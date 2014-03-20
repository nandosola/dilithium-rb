module Dilithium
  module PersistenceExceptions
    class IllegalUpdateError < StandardError; end
    class ImmutableObjectError < StandardError; end
  end
end