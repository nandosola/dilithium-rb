# -*- encoding : utf-8 -*-

module Dilithium
# Layer Super-Type that handles only identifier and attributes. No references of any kind.
  class DomainObject
    extend BaseMethods::Attributes
    extend BaseMethods::References

    class << self
      alias_method :base_add_attribute, :add_attribute
    end

    def _type
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

    def initialize(in_h={})
      check_input_h(in_h)
      load_attributes(in_h)
    end


    protected

    def load_attributes(in_h)
      #TODO This loads the default attributes for each type (i.e. an empty Array for children). This should actually
      # be done in each load_xxx method instead of here
      self.class.attribute_descriptors.each do |k,v|
        instance_variable_set("@#{k}".to_sym, v.default) unless v.is_a? BasicAttributes::ParentReference
      end

      load_self_attributes(in_h) unless in_h.empty?
    end

    def check_input_h(in_h)
      raise ArgumentError, "BaseEntity must be initialized with a Hash - got: #{in_h.class}" unless in_h.is_a?(Hash)
      unless in_h.empty?
        # TODO: check_reserved_keys(in_h) => :metadata
        attributes = self.class.attribute_descriptors
        attr_keys = attributes.keys
        in_h.each do |k,v|
          base_name = k.to_s.chomp("_id").to_sym
          if attributes.include?(k)
            attribute_name = k
          elsif [BasicAttributes::ImmutableReference, BasicAttributes::ImmutableMultiReference].include?(attributes[base_name].class)
            attribute_name = base_name
            v = {:id => v}
          end

          raise ArgumentError, "Attribute #{k} is not allowed in #{self.class}" unless attr_keys.include?(attribute_name)

          attributes[base_name].check_constraints(v)
        end
      end
    end

    private

    def load_self_attributes(in_h)
      self.class.attributes.select { |attr| attr.is_attribute? }.each do |attr|
        attr_name = attr.name
        value = if in_h.include?(attr_name)
                  attr_value = in_h[attr_name]

                  if attr.is_a?(BasicAttributes::ValueReference) && attr_value.is_a?(Hash)
                    keys = attr.type.identifier_names.map{ |id| attr_value[id]}
                    Repository.for(attr.type).fetch_by_id(*keys)
                  else
                    attr_value
                  end
                else
                  attr.default
                end

        send("#{attr_name}=".to_sym,value)

        #TODO Should we actually destroy the Hash?
        in_h.delete(attr_name)
      end
    end
  end
end