require 'lib/exceptions'
require 'lib/uuid_generator'
require 'lib/registry'

# CAVEAT: this is not threadsafe nor distribution-friendly
# Code smell caveat:
# These methods are needed for concurrency control and should be included in the domain object
# this is an optimization so that there's no need to build/traverse a list.
# TODO maybe the registry should store nodename/class/id/UoW/state - this would allow easier distribution!
module UnitOfWorkEntityService
  def assign_unit_of_work(uow, state)
    units_of_work[uow.uuid] = state
  end

  def unassign_unit_of_work(uow)
    units_of_work.delete(uow.uuid)
  end

  def units_of_work
    @units_of_work ||= {} # do not maintain state
  end

  def has_unit_of_work?
    !unit_of_work.empty?
  end
end

class ObjectTracker
  attr_reader :allowed_states

  protected
  class TrackedObject
    attr_accessor :object, :state

    def initialize(obj, st, outer)
      @object = obj
      @state = st
      @parent = outer
      check_valid_state(st)
    end

    def state=(st)
      check_valid_state(st)
      @state = st
    end

    def check_valid_state(st)
      raise RuntimeError, "State is not valid. Allowed states are #{@parent.allowed_states}" unless \
        @parent.allowed_states.include?(st)
    end
  end

  public
  class TrackedObjectSearchResult
    ARRAY_T = :array; SINGLE_T = :single
    RETURN_TYPES = [ARRAY_T, SINGLE_T]
    attr_reader :object, :state

    class << self
      protected :new
    end

    def initialize(tracked_object)
      @object = tracked_object.object
      @state = tracked_object.state
    end

    def self.factory(results, return_type=ARRAY_T)
      TrackedObjectSearchResult.check_results_array(results)

      if RETURN_TYPES.include?(return_type)

        if SINGLE_T == return_type
          TrackedObjectSearchResult.check_single_or_empty_result(results)
        end

        if results.nil? || results.empty?
          (SINGLE_T == return_type) ? nil : []
        else
          res = results.map {|to| TrackedObjectSearchResult.new(to)}
          (SINGLE_T == return_type) ? res.first : res
        end

      else
        raise ArgumentError, "Unknown return_type: #{return_type}. Valid types are: #{RETURN_TYPES}"
      end
    end

    def self.check_results_array(results)
      unless results.is_a?(Array)
        raise ArgumentError, "First argument must be an Array. Found: #{results.class} instead"
      end
    end

    def self.check_single_or_empty_result(results)
      if 1 < results.count
        raise RuntimeError, "Found same object #{results.count} times!"
      end
    end
  end

  def initialize(states_array)
    @allowed_states = states_array
    @tracker = []
  end

  def track(obj, st)
    @tracker<< TrackedObject.new(obj, st, self) if fetch_tracked_object(obj).nil?
  end
  alias_method :add, :track

  def untrack(obj)
    tracked_object = fetch_tracked_object(obj)
    ObjectTracker.check_not_nil(tracked_object)
    @tracker.delete(tracked_object)
  end
  alias_method :delete, :untrack

  def change_object_state(obj, st)
    tracked_object = fetch_tracked_object(obj)
    ObjectTracker.check_not_nil(tracked_object)
    tracked_object.state = st
  end

  def fetch_by_state(st)
    found_array = @tracker.select {|to| st == to.state}
    TrackedObjectSearchResult.factory(found_array)
  end

  def fetch_object(obj)
    found_array = @tracker.select {|to| obj === to.object}
    TrackedObjectSearchResult.factory(found_array, TrackedObjectSearchResult::SINGLE_T)
  end

  def fetch_by_class(klazz, search_id=nil)
    filter = lambda do |obj|
      if search_id.nil?
        obj.object.is_a?(klazz)
      else
        obj.object.is_a?(klazz) && search_id == obj.object.id
      end
    end
    found_array = @tracker.select {|to| filter.call(to) }

    if search_id.nil?
      TrackedObjectSearchResult.factory(found_array)
    else
      TrackedObjectSearchResult.factory(found_array, TrackedObjectSearchResult::SINGLE_T)
    end
  end

  private
  def fetch_tracked_object(obj)
    found_array = @tracker.select {|to| obj === to.object}
    TrackedObjectSearchResult.check_single_or_empty_result(found_array)
    found_array[0]
  end

  def self.check_not_nil(tracked_object)
    if tracked_object.nil?
      raise RuntimeError, "Object #{obj.inspect} is not tracked!"
    else
      tracked_object
    end
  end
end

class UnitOfWork
  STATE_NEW = :new
  STATE_DIRTY = :dirty
  STATE_CLEAN = :clean
  STATE_DELETED = :removed
  ALL_STATES = [STATE_NEW, STATE_DIRTY, STATE_CLEAN, STATE_DELETED]
  attr_reader :uuid, :valid, :committed

  def initialize
    @uuid = UUIDGenerator.generate
    @valid = true
    @committed = false
    @object_tracker = ObjectTracker.new(ALL_STATES)
    UnitOfWorkRegistry::Registry.instance<< self
  end

  def self.mapper= mapper
    raise RuntimeError, "Mapper can only be defined once" unless @mapper.nil?
    @@mapper = mapper
  end

  def fetch_object_by_id(obj_class, obj_id)
    @object_tracker.fetch_by_class(obj_class, obj_id)
  end

  def fetch_object(obj)
    @object_tracker.fetch_object(obj)
  end

  def register_clean(obj)
    check_register_clean(obj)
    register_entity(obj, STATE_CLEAN)
  end

  def register_dirty(obj)
    check_register_dirty(obj)
    register_entity(obj, STATE_DIRTY)
  end

  def register_deleted(obj)
    check_register_dirty(obj)
    register_entity(obj, STATE_DELETED)
  end

  def register_new(obj)
    check_register_dirty(obj)
    register_entity(obj, STATE_NEW)
  end

  def check_register_clean(obj)
    true
  end

  def check_register_dirty(obj)
    true
  end

  def check_register_deleted(obj)
    true
  end

  def check_register_new(obj)
    true
  end

  def rollback
    check_valid_uow
    @object_tracker.fetch_by_state(STATE_DIRTY).each { |res| @@mapper.reload(res.object) }
    @object_tracker.fetch_by_state(STATE_DELETED).each { |res| @@mapper.reload(res.object) }

    move_all_objects(STATE_DELETED, STATE_DIRTY)
    @committed = true
  end

  def commit
    check_valid_uow

    # TODO: Check optimistic concurrency (in a subclass)
    # TODO handle Sequel::DatabaseError
    @@mapper.transaction do
      @object_tracker.fetch_by_state(STATE_NEW).each { |res| @@mapper.save(res.object) }
      @object_tracker.fetch_by_state(STATE_DIRTY).each { |res| @@mapper.save(res.object) }
      @object_tracker.fetch_by_state(STATE_DELETED).each { |res| @@mapper.delete(res.object) }

      clear_all_objects_in_state(STATE_DELETED)
      move_all_objects(STATE_NEW, STATE_DIRTY)
      @committed = true
    end
  end

  def complete
    check_valid_uow
    #TODO Perhaps check the actual saved status of objects in memory?
    raise RuntimeError, "Cannot complete without commit/rollback" unless @committed

    ALL_STATES.each { |st| clear_all_objects_in_state(st) }
    UnitOfWorkRegistry::Registry.instance.delete(self)
    @valid = false
  end

  private
  def register_entity(obj, state)
    check_valid_uow

    res = @object_tracker.fetch_object(obj)
    if res.nil?
      @object_tracker.track(obj, state)
    else
      @object_tracker.change_object_state(res.object, state)
    end
    obj.assign_unit_of_work(self, state)
    @committed = false
  end

  def move_all_objects(from_state, to_state)
    @object_tracker.fetch_by_state(from_state).each do |res|
      res.object.assign_unit_of_work(self, to_state)
      @object_tracker.change_object_state(res.object, to_state)
    end
  end

  def clear_all_objects_in_state(state)
    @object_tracker.fetch_by_state(state).each do |res|
      res.object.unassign_unit_of_work(self)
      @object_tracker.untrack(res.object)
    end
  end

  def check_valid_uow
    raise RuntimeError, "Invalid Unit of Work" unless @valid
  end
end

class ReadWriteLockingUnitOfWork < UnitOfWork
  def check_register_clean(obj)
    raise ConcurrencyException, 'object is not clean' unless \
      obj.unit_of_work.nil? || obj.unit_of_work[:state] == STATE_CLEAN
  end

  def check_register_dirty(obj)
    raise ConcurrencyException, 'object is not clean' unless obj.unit_of_work.nil?
  end

  def check_register_deleted(obj)
    raise ConcurrencyException, 'object is not clean' unless obj.unit_of_work.nil?
  end
end
