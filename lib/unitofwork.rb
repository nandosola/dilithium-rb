require 'lib/exceptions'
require 'lib/uuid_generator'

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
      raise RuntimeException, "State is not valid. Allowed states are #{@parent.allowed_states}" unless \
        @parent.allowed_states.include?(st)
    end
  end

  def initialize(states_array)
    @allowed_states = states_array
    @tracker = []
  end

  def track(obj, st)
    @tracker<< TrackedObject.new(obj, st, self) if find_object(obj).nil?
  end
  alias_method :add, :track

  def untrack(tracked_obj)
    if tracked_obj.is_a?(TrackedObject)
      @tracker.delete(tracked_obj)
    else
      raise ArgumentError, "Only a TrackedObject can be untracked. Got: #{tracked_obj.class}"
    end
  end
  alias_method :delete, :untrack

  def find_object(obj)
    found_obj = @tracker.select {|to| obj === to.object}
    if found_obj.empty?
      nil
    else
      if 1 == found_obj.count
        found_obj.first
      else
        raise RuntimeException, "Found same tracked object in #{found_obj.count} different states"
      end
    end
  end

  def find_by_state(st)
    @tracker.select {|to| st == to.state}
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
  end

  def self.mapper= mapper
    raise RuntimeError, "Mapper can only be defined once" unless @mapper.nil?
    @@mapper = mapper
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
    @object_tracker.find_by_state(STATE_DIRTY).each { |tr_obj| @@mapper.reload(tr_obj.object) }
    @object_tracker.find_by_state(STATE_DELETED).each { |tr_obj| @@mapper.reload(tr_obj.object) }

    move_all_objects(STATE_DELETED, STATE_DIRTY)
    @committed = true
  end

  def commit
    check_valid_uow

    # TODO: Check optimistic concurrency (in a subclass)
    @@mapper.transaction do
      @object_tracker.find_by_state(STATE_NEW).each { |tr_obj| @@mapper.save(tr_obj.object) }
      @object_tracker.find_by_state(STATE_DIRTY).each { |tr_obj| @@mapper.save(tr_obj.object) }
      @object_tracker.find_by_state(STATE_DELETED).each { |tr_obj| @@mapper.delete(tr_obj.object) }

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
    # TODO: Remove UOW from the Registry
    @valid = false
  end

  private
  def register_entity(obj, state)
    check_valid_uow

    found_tr_obj = @object_tracker.find_object(obj)
    if found_tr_obj.nil?
      @object_tracker.track(obj, state)
    else
      found_tr_obj.state = state
    end
    obj.assign_unit_of_work(self, state)
    @committed = false
  end

  def move_all_objects(from_state, to_state)
    @object_tracker.find_by_state(from_state).each do |tr_obj|
      tr_obj.object.assign_unit_of_work(self, to_state)
      tr_obj.state = to_state
    end
  end

  def clear_all_objects_in_state(state)
    @object_tracker.find_by_state(state).each do |tr_obj|
      tr_obj.object.unassign_unit_of_work(self)
      @object_tracker.untrack(tr_obj)
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
