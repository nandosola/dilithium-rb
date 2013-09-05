require_relative 'object_history'

module UnitOfWork

  # CAVEAT: this is not threadsafe nor distribution-friendly
  class Transaction

    STATE_NEW = :new
    STATE_DIRTY = :dirty
    STATE_CLEAN = :clean
    STATE_DELETED = :removed
    ALL_STATES = [STATE_NEW, STATE_DIRTY, STATE_CLEAN, STATE_DELETED]
    attr_reader :uuid, :valid, :committed

    def initialize(mapper_class)
      @uuid = UUIDGenerator.generate
      @valid = true
      @committed = false
      @object_tracker = ObjectTracker.new(ALL_STATES)
      @history = ObjectHistory.new
      @mapper = mapper_class
      TransactionRegistry::Registry.instance<< self
    end

    def fetch_object_by_id(obj_class, obj_id)
      @object_tracker.fetch_by_class(obj_class, obj_id)
    end

    def fetch_object(obj)
      @object_tracker.fetch_object(obj)
    end

    def fetch_object_by_class(obj_class)
      @object_tracker.fetch_by_class(obj_class)
    end

    # TODO only is_a?BasicEntity can be registered in a transaction

    def register_clean(obj)
      check_register_clean(obj)
      register_entity(obj, STATE_CLEAN)
    end

    def register_dirty(obj)
      check_register_dirty(obj)
      register_entity(obj, STATE_DIRTY)
    end

    def register_deleted(obj)
      check_register_deleted(obj)
      register_entity(obj, STATE_DELETED)
    end

    def register_new(obj)
      check_register_new(obj)
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
      #TODO handle nested transactions (@history)
      @object_tracker.fetch_by_state(STATE_DIRTY).each { |res| @mapper.reload(res.object) }
      @object_tracker.fetch_by_state(STATE_DELETED).each { |res| @mapper.reload(res.object) }

      move_all_objects(STATE_DELETED, STATE_DIRTY)
      @committed = true
    end

    def commit
      check_valid_uow

      # TODO: Check optimistic concurrency (in a subclass) - it has an additional :stale state
      # TODO handle Repository::DatabaseError
      @mapper.transaction do  #TODO make sure this is a deferred transaction

        @object_tracker.fetch_by_state(STATE_NEW).each do |res|
          working_obj = res.object
          @mapper.insert(working_obj)
          @history << working_obj
        end

        @object_tracker.fetch_by_state(STATE_DIRTY).each do |res|
          working_obj = res.object
          orig_obj = @history[working_obj.object_id].last
          @mapper.update(working_obj, orig_obj)
          @history << working_obj
        end

        #TODO handle nested transactions (@history)
        @object_tracker.fetch_by_state(STATE_DELETED).each do |resource|
          @mapper.delete(resource.object)
        end

        #update_inserted_entities(inserted_entities)
        #remove_deleted_entities(deleted_entities)
        clear_all_objects_in_state(STATE_DELETED)

        move_all_objects(STATE_NEW, STATE_DIRTY)

        @committed = true
      end
    end

    private

    def update_inserted_entities(entities)
      entities.each do |entity, ids|
        entity.id = ids[:id]
        if entity.class.has_parent?
          #entity.send("#{@mapper.to_parent_reference(entity)}=", ids[:parent_id])
        else
          @object_tracker.change_object_state(entity, STATE_DIRTY)
        end
      end
    end

    # TODO
    def remove_deleted_entities(entities)
      entities.each do |entity, id|
        parent_type = entity.class.parent_reference
        if parent_type
          pp "---------------------------------", entity.send(entity.class.parent_reference)
        else
          @object_tracker.untrack(entity)
        end
      end
    end

    public

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
      @history << obj
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
