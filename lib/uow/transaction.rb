require_relative 'object_history'
require_relative 'states'

module UnitOfWork

  # CAVEAT: this is not threadsafe nor distribution-friendly
  class Transaction

    include TransactionExceptions
    include States::Default

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

    def fetch_all_objects
      @object_tracker.fetch_all
    end

    def register_clean(obj)
      check_valid_entity(obj, STATE_CLEAN)
      register_entity(obj, STATE_CLEAN)
    end

    def register_dirty(obj)
      check_valid_entity(obj, STATE_DIRTY)
      register_entity(obj, STATE_DIRTY)
    end

    def register_deleted(obj)
      check_valid_entity(obj, STATE_DELETED)
      register_entity(obj, STATE_DELETED)
    end

    def register_new(obj)
      check_valid_entity(obj, STATE_NEW, false)
      register_entity(obj, STATE_NEW)
    end

    # Methods to be overriden by subclasses (ie. concurrency control)
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
    # /end overridable methods

    def rollback
      check_valid_uow
      #TODO handle nested transactions (@history)
      @object_tracker.fetch_all.each do |res|
        unless [STATE_CLEAN, STATE_NEW].include?(res.state)
          working_obj = res.object
          restored_obj = @history[working_obj.object_id].last
          unless restored_obj.nil?
            restored_payload = EntitySerializer.to_nested_hash(restored_obj)

            # The version is only incremented during a successful DB update,
            # so working_obj._version payload is still valid
            working_obj.full_update(EntitySerializer.strip_key_from_hash(restored_payload, :_version))

          else
            id = res.object.id
            RuntimeError "Cannot rollback #{res.object.class} with identity (id=#{id.nil? ? 'nil' : id })\n"+
                             "-- it couldn't be found in history[object_id=#{working_obj.object_id}]"
          end
        end
      end
      move_all_objects(STATE_DELETED, STATE_DIRTY)
      move_all_objects(STATE_DELETED, STATE_DIRTY)
      @committed = true
    end

    def commit
      check_valid_uow

      # TODO handle Repository::DatabaseError
      # TODO: store entity's latest payload before commit() and restore it
      begin
        @mapper.transaction do

          @object_tracker.fetch_in_dependency_order(STATE_NEW).each do |res|
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
          @object_tracker.fetch_by_state(STATE_DELETED).each do |res|
            @mapper.delete(res.object)
          end

          clear_all_objects_in_state(STATE_DELETED)

          move_all_objects(STATE_NEW, STATE_DIRTY)

          @committed = true
        end
      rescue ObjectTrackerExceptions::UntrackedReferenceException => ex
        register_new(ex.untracked_reference)
        commit
      end
    end

    def complete
      check_valid_uow
      #TODO Perhaps check the actual saved status of objects in memory?
      raise RuntimeError, "Cannot complete without commit/rollback" unless @committed
      end_transaction
    end
    alias_method :finalize, :complete

    def abort
      check_valid_uow
      end_transaction
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

    def check_valid_entity(obj, state, must_have_id=true)
      unless obj.class < BaseEntity
        raise ArgumentError, "Only BasicEntities can be registered in the Transaction. Got: #{obj.class}"
      end

      id = BaseEntity::PRIMARY_KEY[:identifier]

      if must_have_id
        raise ArgumentError, "Cannot register #{obj.class} without an identity (#{id})" if obj.id.nil?
        found_res = fetch_object_by_id(obj.class, obj.id)
        unless found_res.nil? || found_res.object.id.nil?
          if found_res.state == state
            raise ArgumentError, "Cannot register #{obj.class} with identity (#{id}=#{obj.id}): already exists in the transaction"
          end
        end
      else
        raise ArgumentError, "Cannot register #{obj.class} with an existing identity (#{id}=#{obj.id})" unless obj.id.nil?
        found_res = fetch_object(obj)
        unless found_res.nil?
          if found_res.state == state
            raise ArgumentError, "Cannot register the same object twice: already exists in the transaction"
          end
        end
      end
    end

    def check_valid_uow
      raise RuntimeError, "Invalid Transaction" unless @valid
    end

    def end_transaction
      ALL_STATES.each { |st| clear_all_objects_in_state(st) }
      TransactionRegistry::Registry.instance.delete(self)
      @valid = false
    end

  end

  # TODO: Check optimistic concurrency (in a subclass) - it has an additional :stale state
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