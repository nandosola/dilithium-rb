require 'base_methods'

# Layer Super-Type that handles only identifier and attributes. No references of any kind.
class DomainObject
  extend BaseMethods

  PRIMARY_KEY = {:identifier=>:id, :type=>Integer}

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

      def attribute_descriptors
        self.superclass.attribute_descriptors.merge(@attributes)
      end

      def add_attribute(descriptor)
        name = descriptor.name
        raise ArgumentError, "Duplicate definition for #{name}" if @attributes.has_key?(name)

        @attributes[name] = descriptor
        attach_attribute_accessors(descriptor)
      end


      @attributes = { }

      # TODO :id should be a IdentityAttribute, with a setter that prevents null assignation
      add_attribute(BasicAttributes::GenericAttribute.new(PRIMARY_KEY[:identifier], PRIMARY_KEY[:type]))
    end
  end

  def self.attach_attribute_accessors(attribute_descriptor)
    name = attribute_descriptor.name

    self.class_eval do
      define_method(name){instance_variable_get("@#{name}".to_sym)}
      define_method("#{name}="){ |new_value|
            self.class.attribute_descriptors[name].check_constraints(new_value)
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

