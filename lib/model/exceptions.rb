module Dilithium
  module DomainObjectExceptions
    class ConfigurationError < StandardError; end
    class ImmutableObjectError < StandardError; end
  end
end