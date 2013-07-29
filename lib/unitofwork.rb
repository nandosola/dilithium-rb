require 'lib/exceptions'
require 'lib/uuid_generator'


=begin
require 'singleton'
class UnitOfWorkRegistry
  include Singleton
  # TODO create/read file for each UOW
  def marshall
  end
  def unmarshall
  end
end

$unit_of_work_registry = UnitOfWorkRegistry.new
=end

# Code smell caveat:
# These methods are needed for concurrency control and should be included in the domain object
# this is an optimization so that there's no need to build/traverse a list.
# TODO maybe the registry should store nodename/class/id/UoW/state - this would allow easier distribution!
module UnitOfWorkMixin
  def assign_unit_of_work(uow, state)
    # TODO Tell Repository that this object belongs to this UOW so that it can cache it
    units_of_work[uow.uuid] = state
  end

  def unassign_unit_of_work(uow)
    # TODO Tell Repository that this object doesn't belong to this UOW any more
    units_of_work.delete(uow.uuid)
  end

  def units_of_work
    @units_of_work ||= {}
  end

  def has_unit_of_work?
    !unit_of_work.empty?
  end
end

# CAVEAT: this is not threadsafe nor distribution-friendly
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
    @tracked_objects = {}
    ALL_STATES.each { |st| @tracked_objects[st] = []}
  end

  def self.mapper= mapper
    raise RuntimeError, "Mapper can only be defined once" unless @mapper.nil?
    @@mapper = mapper
  end

  def self.find_by_id id
  end

  def self.find_by_object obj
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

  def register_entity(obj, state)
    raise RuntimeError, "Invalid Unit of Work" unless @valid

    old_state = obj.units_of_work[self.uuid]
    @tracked_objects[old_state].delete obj unless old_state.nil?
    @tracked_objects[state] << obj

    obj.assign_unit_of_work(self, state)
    @committed = false
  end

  def rollback
    raise RuntimeError, "Invalid Unit of Work" unless @valid
    @tracked_objects[STATE_DIRTY].each { |obj| @@mapper.reload(obj) }
    @tracked_objects[STATE_DELETED].each { |obj| @@mapper.reload(obj) }

    move_all_objects(STATE_DELETED, STATE_DIRTY)
    @committed = true
  end

  def commit
    raise RuntimeError, "Invalid Unit of Work" unless @valid

    # TODO: Check optimistic concurrency (in a subclass)
    @@mapper.transaction do
      @tracked_objects[STATE_NEW].each { |obj| @@mapper.save(obj) }
      @tracked_objects[STATE_DIRTY].each { |obj| @@mapper.save(obj) }
      @tracked_objects[STATE_DELETED].each { |obj| @@mapper.delete(obj) }

      clear_state(STATE_DELETED)
      move_all_objects(STATE_NEW, STATE_DIRTY)
      @committed = true
    end
  end

  def complete
    raise RuntimeError, "Invalid Unit of Work" unless @valid
    #TODO Perhaps check the actual saved status of objects in memory?
    raise RuntimeError, "Cannot complete without commit/rollback" unless @committed

    ALL_STATES.each { |st| clear_state(st) }

    # TODO: Remove UOW from the Registry

    @valid = false
  end

  private

  def move_all_objects(from, to)
    @tracked_objects[from].each { |obj| obj.assign_unit_of_work(self, to) }
    @tracked_objects[to] += @tracked_objects[from]
    @tracked_objects[from].clear
  end

  def clear_state(state)
    @tracked_objects[state].each { |obj| obj.unassign_unit_of_work(self)}
    @tracked_objects[state].clear
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
