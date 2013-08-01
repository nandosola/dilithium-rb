# CAVEAT: this is not threadsafe nor distribution-friendly

module UnitOfWork
  class Transaction
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
      TransactionRegistry::Registry.instance<< self
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
      # TODO handle Repository::DatabaseError
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
      TransactionRegistry::Registry.instance.delete(self)
      @valid = false
    end

    private
    def register_entity(obj, state)
      check_valid_uow

      res = @object_tracker.fetch_object(obj)
      if res.nil?
        @object_tracker.track(obj, state)
      else
        # TODO validate state transitions (ie. DIRTY-> CLEAN)
        @object_tracker.change_object_state(res.object, state)
      end
      @committed = false
    end

    def move_all_objects(from_state, to_state)
      @object_tracker.fetch_by_state(from_state).each do |res|
        @object_tracker.change_object_state(res.object, to_state)
      end
    end

    def clear_all_objects_in_state(state)
      @object_tracker.fetch_by_state(state).each do |res|
        @object_tracker.untrack(res.object)
      end
    end

    def check_valid_uow
      raise RuntimeError, "Invalid Transaction" unless @valid
    end
  end

=begin TODO
    class ReadWriteLockingTransaction < Transaction
      def check_register_clean(obj)
        raise ConcurrencyException, 'object is not clean' unless \
          obj.transaction.nil? || obj.unit_of_work[:state] == STATE_CLEAN
      end

      def check_register_dirty(obj)
        raise ConcurrencyException, 'object is not clean' unless obj.transaction.nil?
      end

      def check_register_deleted(obj)
        raise ConcurrencyException, 'object is not clean' unless obj.transaction.nil?
      end
    end
=end
end
