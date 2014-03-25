module Dilithium
  module PersistenceExceptions
    class IllegalUpdateError < StandardError; end
    class ImmutableObjectError < StandardError; end
    class NotFound < StandardError; end
    class NotImplemented < StandardError; end
  end
end