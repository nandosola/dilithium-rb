# -*- encoding : utf-8 -*-
require 'observer'

module Dilithium
# Layer Super-Type that handles only identifier and attributes. No references of any kind.
class DomainObject
  extend BaseMethods
  include Observable

  PRIMARY_KEY = {:identifier => :id, :type => Integer}

  def self.pk
    PRIMARY_KEY[:identifier]
  end

  def type
    self.class
  end

  def self.attribute_descriptors
    {}
  end

  def self.inherited(base)

    base.instance_eval do
      def attributes
        self.attribute_descriptors.values
      end

      def attribute_names
        self.attribute_descriptors.keys
      end

      def attribute_descriptors
        self.superclass.attribute_descriptors.merge(@attributes)
      end

      def each_attribute(*attr_classes)
        self.attributes.each { |attr| yield attr if attr_classes.include?(attr.class) }
      end

      def add_attribute(descriptor)
        name = descriptor.name
        raise ArgumentError, "Duplicate definition for #{name}" if @attributes.has_key?(name)

        @attributes[name] = descriptor
        self.attach_attribute_accessors(descriptor)
      end

      @attributes = { }

      base.add_pk_attribute
    end
  end

  def self.add_pk_attribute
    @attributes[pk] = BasicAttributes::GenericAttribute.new(pk, PRIMARY_KEY[:type])

    self.class_eval do

      define_method(pk){instance_variable_get("@#{self.class.pk}".to_sym)}

      # TODO Should this be a new class (IdentityAttribute)?
      define_method("#{pk}="){ |new_value|
        pk_name = "@#{self.class.pk}".to_sym
        old_value = instance_variable_get(pk_name)

        #FIXME This should be removed once we clean up load_attributes/full_update
        return if old_value == new_value

        raise ArgumentError, "Can't reset #{self.class} ID once it has been set. Old value = #{old_value}, new value = #{new_value}" unless old_value.nil?
        raise ArgumentError, "ID must be a #{PRIMARY_KEY[:type]}. It can't be a #{new_value.class}" unless new_value.is_a?(PRIMARY_KEY[:type])

        instance_variable_set(pk_name, new_value)
        changed
        notify_observers(self, self.class.pk, new_value)
      }
    end

  end

  def self.attach_attribute_accessors(attribute_descriptor)
    name = attribute_descriptor.name

    self.class_eval do
      define_method(name){instance_variable_get("@#{name}".to_sym)}
      define_method("#{name}="){ |new_value|
        attribute_descriptor.check_constraints(new_value)
        instance_variable_set("@#{name}".to_sym, new_value)
      }
    end
  end

  def self.get_attributes_by_type(type)
    attrs = self.attributes
    refs = attrs.reduce([]){|m,attr| attr.instance_of?(type) ? m<<attr.name : m }
    refs
  end

  def self.extended_generic_attributes
    self.get_attributes_by_type(BasicAttributes::ExtendedGenericAttribute)
  end

  def self.has_extended_generic_attributes?
    !self.extended_generic_attributes.empty?
  end
end
end