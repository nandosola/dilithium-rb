# -*- encoding : utf-8 -*-

module Dilithium
  class BaseValue < ImmutableDomainObject
    include DomainObjectExceptions

    extend BaseMethods::Attributes
    extend Repository::Sequel::ValueClassBuilders

    def self.inherited(base)
      base.instance_eval do
        @attributes = {}
        @identifiers = []

        add_attribute(BasicAttributes::GenericAttribute.new(:active, TrueClass, false, true)) unless attribute_descriptors.has_key? :active
      end

      PersistenceService.add_table(base)
    end

    def self.identified_by(*attributes)
      raise ConfigurationError, 'identified_by can only be called once' unless @identifiers.empty?

      @identifiers = attributes.map do |attr_name|
        attr_name.to_sym.tap do |attr_sym|
          raise ArgumentError, ":#{attr_sym} must be defined as an attribute" unless @attributes.key? attr_sym
        end
      end
    end

    def self.identifier_names
      @identifiers
    end

    def self.identifiers
      @identifiers.map do |id|
        { :identifier => id, :type => self.attribute_descriptors[id].type }
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