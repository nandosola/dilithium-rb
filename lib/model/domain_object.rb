# -*- encoding : utf-8 -*-

module Dilithium
# Layer Super-Type that handles only identifier and attributes. No references of any kind.
  class DomainObject
    extend BaseMethods::Attributes
    extend BaseMethods::References

    class Namespace
      class Path
        SEPARATOR = '::'
        @array = []
        def initialize(path)
          @array = path || @array
        end
        def parent
          path = to_a
          Path.new(path[0..-2])
        end
        def to_a
          @array.dup
        end
        def to_class
          @array.reduce(Object){ |m,c| m.const_get(c) }
        end
      end

      attr_reader :full_path, :module_path
      def initialize(klazz)
        path = klazz.to_s.split(Path::SEPARATOR)
        @full_path = Path.new(path)
        @module_path = @full_path.parent
      end
      def append_to_module_path(literal, as_constant=false)
        path = Path.new(@module_path.to_a + [camelize(literal)])
        as_constant ? path.to_class : path
      end
      private
      def camelize(literal)
        literal.to_s.singularize.camelize
      end
    end

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
        @namespace = Namespace.new(self)

        def ns
          @namespace
        end

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
      self.attributes.reduce([]){|m,attr| attr.is_a?(type) ? m<<attr.name : m }
    end

    def self.extended_generic_attributes
      self.get_attributes_by_type(BasicAttributes::ExtendedGenericAttribute)
    end

    def self.has_extended_generic_attributes?
      !self.extended_generic_attributes.empty?
    end

    def self.build(&b)
      obj = self.send(:new)
      finish_build(obj, &b)
    end

    # Extract this to another method so we can do stuff after creating the object and before assembling
    # it (i.e. _version in BaseEntity)
    def self.finish_build(obj)
      obj.send(:_add_collections)
      yield obj if block_given?
      obj.send(:_add_default_attributes)
      obj.send(:_validate)
      obj
    end

    def update!(&b)
      b.call(obj) unless b.nil?
      _validate
      self
    end

    private

    def _validate
      #TODO Invariants
      self.class.attributes.each do |attr|
        if attr.respond_to?(:mandatory) && attr.mandatory && self.send(attr.name).nil?
          raise DomainObjectExceptions::ValidationFailed, "Attribute #{attr.name} is mandatory"
        end
      end
    end

    def _add_default_attributes
      self.class.attributes.each do |attr|
        if attr.respond_to?(:default) && ! attr.default.nil? && instance_variable_get("@#{attr.name}".to_sym).nil?
          instance_variable_set("@#{attr.name}".to_sym, attr.default)
        end
      end
    end

    def _add_collections
      self.class.get_attributes_by_type(BasicAttributes::ListReference).each do |attr|
        attr_name = "@#{attr}".to_sym
        current = instance_variable_get(attr_name)
        instance_variable_set(attr_name, Array.new) if current.nil?
      end
    end

    # You should use the .build method to create DomainObjects and their subclasses
    private_class_method :new
  end
end