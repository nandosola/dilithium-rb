module UnitOfWork

  module TransactionExceptions

    class IllegalOperationException < Exception; end

    class ObjectNotFoundInTransactionException < Exception; end

    module Concurrency
      class ReadWriteLockException < Exception
        attr_reader :entity_class, :id, :operation
        def initialize(entity_class, id, operation)
          @entity_class = entity_class
          @id = id
          @operation = operation
          super()
        end
      end
    end
  end

  module ObjectTrackerExceptions

    class InvalidStateException < Exception; end

    class MultipleTrackedObjectsException < Exception; end

    class UntrackedObjectException < Exception; end

    class UntrackedReferenceException < UntrackedObjectException
      attr_reader :untracked_reference
      def initialize(ref, tracker)
        msg =<<-EOF
            Reference #{ref.inspect} has no ID and it's used by entities in this tracker,
            but is not tracked by ObjectTracker #{tracker}!
        EOF
        super(msg)
        @untracked_reference = ref
      end
    end

  end
end
