# -*- encoding : utf-8 -*-

module Dilithium
  class BaseValue < DomainObject
    include DomainObjectExceptions

    extend BaseMethods::Attributes

    def self.inherited(base)
      base.instance_eval do
        @attributes = {}
        @identifiers = []
      end
    end

    def self.identified_by(*attributes)
      raise ConfigurationError, 'identified_by can only be called once' unless @identifiers.empty?

      @identifiers = attributes.map do |attr_name|
        attr_name.to_sym.tap do |attr_sym|
          raise ArgumentError, ":#{attr_sym} must be defined as an attribute" unless @attributes.key? attr_sym
        end
      end
    end

    def ==(other)
      self.class.attribute_names.inject(true) do |memo, attr_name|
        var_name = "@#{attr_name}".to_sym
        memo && instance_variable_get(var_name) == other.instance_variable_get(var_name)
      end
    end
  end
end