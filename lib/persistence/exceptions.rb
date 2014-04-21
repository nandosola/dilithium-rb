module Dilithium
  module PersistenceExceptions
    class IllegalUpdateError < StandardError; end
    class ValueAlreadyExistsError < StandardError; end
    class ImmutableObjectError < StandardError; end
    class NotImplemented < StandardError; end

    class NotFound < StandardError
      attr_accessor :id, :type
      def initialize(id, type)
        super("#{type} with ID #{id} not found")
        @id = id
        @type = type
      end
    end
  end
end