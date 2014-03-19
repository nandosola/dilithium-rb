module Dilithium
  module DomainObjectExceptions
    class ConfigurationError < StandardError; end
    class ImmutableError < StandardError; end
  end
end