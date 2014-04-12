# -*- encoding : utf-8 -*-

module Dilithium
  class BaseValue < ImmutableDomainObject
    include DomainObjectExceptions

    extend BaseMethods::Attributes
    extend Repository::Sequel::ValueClassBuilders

    def self.inherited(base)
      base.instance_eval do

        # You should use the .build method to create DomainObjects and their subclasses
        base.private_class_method :new

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

    def identifiers
      self.class.identifiers.each_with_object(Hash.new) do |id, h|
        identifier = id[:identifier]
        h[identifier] = instance_variable_get(:"@#{identifier}")
      end
    end

    def each_reference(include_immutable = false)
      # No-op: A BaseValue doesn't have references
    end

    def each_multi_reference(include_immutable = false)
      # No-op: A BaseValue doesn't have references
    end

    def each_child
      # No-op: A BaseValue doesn't have references
    end

    def ==(other)
      self.class.attribute_names.inject(true) do |memo, attr_name|
        var_name = "@#{attr_name}".to_sym
        this_attr = instance_variable_get(var_name)
        other_attr = other.instance_variable_get(var_name)
        memo &&  this_attr == other_attr
      end
    end
  end
end