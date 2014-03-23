module Dilithium
  module PersistenceExceptions
    class IllegalUpdateError < StandardError; end
    class ImmutableObjectError < StandardError; end
    class NotFound < StandardError; end
  end
end