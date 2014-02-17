# -*- encoding : utf-8 -*-
module UnitOfWork

  module TransactionExceptions

    class EntityException < Exception
      attr_reader :entity_class, :id
      def initialize(entity_class, id)
        @entity_class = entity_class
        @id = id
        super()
      end
    end

    class IllegalOperationException < Exception; end

    class ObjectNotFoundInTransactionException < EntityException; end

    module Concurrency
      class ReadWriteLockException < EntityException
        attr_reader :operation
        def initialize(entity_class, id, operation)
          @operation = operation
          super(entity_class, id)
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
