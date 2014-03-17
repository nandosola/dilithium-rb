# -*- encoding : utf-8 -*-

module Dilithium
# Layer Super-Type that handles only identifier and attributes. No references of any kind.
  class DomainObject
    extend BaseMethods::Attributes
    extend BaseMethods::References

    class << self
      alias_method :base_add_attribute, :add_attribute
    end

    def type
      self.class
    end

    def self.attribute_descriptors
      {}
    end

    def self.inherited(base)

      base.instance_eval do

        # TODO Move this into BaseMethods::Attributes
        @attributes = { }

        def attributes
          self.attribute_descriptors.values
        end

        def attribute_names
          self.attribute_descriptors.keys
        end

        def attribute_descriptors
          self.superclass.attribute_descriptors.merge(@attributes)
        end

        def self_attributes
          @attributes.values
        end

        def self_attribute_names
          @attributes.keys
        end

        def self_attribute_descriptors
          @attributes.clone
        end

        def each_attribute(*attr_classes)
          self.attributes.each { |attr| yield attr if attr_classes.include?(attr.class) }
        end

        def add_attribute(descriptor)
          base_add_attribute(descriptor)
          self.attach_attribute_accessors(descriptor)
        end

      end
    end

    def self.attach_attribute_accessors(attribute_descriptor)
      __attr_name = attribute_descriptor.name

      self.class_eval do
        define_method(__attr_name){instance_variable_get("@#{__attr_name}".to_sym)}
        define_method("#{__attr_name}="){ |new_value|
          attribute_descriptor.check_constraints(new_value)
          instance_variable_set("@#{__attr_name}".to_sym, new_value)
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