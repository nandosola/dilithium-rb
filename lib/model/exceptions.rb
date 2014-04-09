module Dilithium
  module DomainObjectExceptions
    class ConfigurationError < StandardError; end
    class ImmutableObjectError < StandardError; end
    class ValidationFailed < StandardError; end
  end
end