# -*- encoding : utf-8 -*-

module Dilithium
  class BaseEntity < DomainObject
    extend Identifiers::Id
    extend Repository::Sequel::EntityClassBuilders
    include Repository::Sequel::EntityInstanceBuilders

    attr_accessor :_version

    # Each BaseEntity subclass will have an internal class called Immutable that contains the immutable representation of
    # said BaseEntity. The Immutable classes are all subclasses of BaseEntity::Immutable
    #TODO See comments for Issue #49: Should we make Immutable a subclass of ImmutableDomainObject?
    class Immutable
      MUTABLE_CLASS = BaseEntity

      def immutable
        self
      end

      def self.inherited(base)
        base.instance_eval do
          def attribute_descriptors
            attribute_names.inject({}) do |memo, name|
              memo[name] = MUTABLE_CLASS.attribute_descriptors[name]
              memo
            end
          end

          def attribute_names
            MUTABLE_CLASS.generic_attributes
          end
        end
      end
    end

    def self.inherited(base)
      DomainObject.inherited(base)
      PersistenceService.add_table(base)

      base.instance_eval do
        # Prevent adding multiple metaprogrammed attrs in the case of BaseEntity sub-subclasses
        add_attribute(BasicAttributes::GenericAttribute.new(:active, TrueClass, false, true)) unless attribute_descriptors.has_key? :active

        # Create the internal Immutable class for this BaseEntity
        immutable_class = Class.new(superclass.const_get(:Immutable))
        immutable_class.const_set(:MUTABLE_CLASS, base)
        const_set(:Immutable, immutable_class)
        add_identifier_accessors
      end
    end

    # Adds children to the current model acting as aggregate root.
    #
    # Example:
    #   class Company < BaseEntity
    #     children :local_offices
    #
    # Params:
    # - (Symbol) *names: list of children
    #
    def self.children(*names)
      names.each do |child|
        # TODO pass type
        self.add_attribute(BasicAttributes::ChildReference.new(child, self))
        self.define_aggregate_method(child)
      end
    end

    # Explicitly creates a parent reference to the aggregate root.
    # It must be used together with #children on the other side of the relationship
    #
    # Example:
    #
    #   class LocalOffice < BaseEntity
    #     children  :addresses
    #     parent :company
    #   ...
    #
    #   class Address < BaseEntity
    #     parent :local_office
    #
    # Params:
    # - (Symbol) parent
    #
    def self.parent(parent)
      self.add_attribute(BasicAttributes::ParentReference.new(parent, self))
    end

    def initialize(in_h={}, parent=nil, aggregate_version=nil)
      check_input_h(in_h)
      set_version_attribute(aggregate_version, parent)
      load_attributes(in_h)
    end

    def full_update(in_h)
      unversioned_h = EntitySerializer.strip_key_from_hash(in_h, :_version)

      self.class.identifier_names.each do |id|
        old_id = instance_variable_get(:"@#{id}")
        raise ArgumentError, "Entity id cannot be changed once defined. Offending key: #{id} new value: '#{unversioned_h[id]}' was: '#{old_id}'" if old_id != unversioned_h[id]
      end

      check_input_h(unversioned_h)
      detach_children
      detach_multi_references
      load_attributes(unversioned_h)
    end

    def make(in_h)
      check_input_h(in_h)
      load_attributes(in_h)
    end

    # Executes a proc for each child, passing child as parameter to proc
    def each_child
      self.class.child_references.each do |child_attr|
        children = Array(self.send(child_attr)).clone
        children.each do |child|
          yield(child)
        end
      end
    end

    def each_reference(include_immutable = false)
      self.class.references(include_immutable).each do |ref_attr|
        refs = Array(self.send(ref_attr)).clone
        refs.each do |ref|
          yield(ref)
        end
      end
    end

    def each_immutable_reference
      self.class.immutable_references.each do |ref_attr|
        refs = Array(self.send(ref_attr)).clone
        refs.each do |ref|
          yield(ref)
        end
      end
    end

    def each_multi_reference(include_immutable = false)
      refs = self.class.multi_references
      refs += self.class.immutable_multi_references if include_immutable

      refs.each do |ref_attr|
        references = Array(self.send(ref_attr)).clone
        references.each do |ref|
          yield(ref, ref_attr)
        end
      end
    end

    def find_multi_reference
      each_multi_reference do |ref, ref_attr|
        return ref if yield(ref, ref_attr)
      end
      nil
    end

    def find_child
      each_child do |child|
        return child if yield(child)
      end
      nil
    end

    # Return an immutable snapshot of this object. The snapshot will be disconnected from its parent and children and
    # any references (i.e., it will contain only GenericAttributes, ExtendedGenericAttributes and its PK). If you need to
    # get a reference to the actual, complete, object you need to use a Finder in the model's Root to get the Entity.
    # Note that the id of the snapshot may be nil (and will never be updated) if you call this method on an Entity that
    # hasn't been persisted.
    def immutable
      obj = self.class.const_get(:Immutable).new
      self.class.attribute_descriptors.each do |name, attr|
        if attr.is_attribute?
          value = self.instance_variable_get(:"@#{name}")
          obj.instance_variable_set(:"@#{name}", value)
        end
      end

      obj
    end

    def self.parent_reference
      parent = self.get_attributes_by_type(BasicAttributes::ParentReference)
      raise RuntimeError, "found multiple parents" unless parent.size < 2
      parent.first
    end

    def self.references(include_immutable = false)
      ret = self.multi_references

      if include_immutable
        ret + self.immutable_references + self.immutable_multi_references
      else
        ret
      end
    end

    def self.generic_attributes
      self.get_attributes_by_type(BasicAttributes::GenericAttribute) + self.get_attributes_by_type(BasicAttributes::ExtendedGenericAttribute)
    end

    def self.multi_references
      self.get_attributes_by_type(BasicAttributes::MultiReference)
    end

    def self.immutable_multi_references
      self.get_attributes_by_type(BasicAttributes::ImmutableMultiReference)
    end

    def self.immutable_references
      self.get_attributes_by_type(BasicAttributes::ImmutableReference)
    end

    def self.value_references
      self.get_attributes_by_type(BasicAttributes::ValueReference)
    end

    def self.child_references
      self.get_attributes_by_type(BasicAttributes::ChildReference)
    end

    def self.has_children?
      !self.child_references.empty?
    end

    def self.has_multi_references?
      !self.multi_references.empty?
    end

    def self.has_parent?
      !self.parent_reference.nil?
    end

    private
    protected

    def set_version_attribute(aggregate_version, parent)
      if parent.nil?
        if aggregate_version.nil?
          @_version = SharedVersion.create(self) # Shared version among all the members of the aggregate
        else
          raise ArgumentError,
                "Version is a #{aggregate_version.class} -- Must be a Version object" unless aggregate_version.is_a?(SharedVersion)
          @_version = aggregate_version
        end
      else
        @_version = parent._version
        #TODO Add child to parent
        parent_attr = parent._type.to_s.split('::').last.underscore.downcase
        instance_variable_set("@#{parent_attr}".to_sym, parent)
      end
    end

    def load_attributes(in_h)
      super

      unless in_h.empty?
        load_immutable_references(in_h)
        load_child_attributes(in_h)
        load_multi_reference_attributes(in_h)
      end
    end

    def load_child_attributes(in_h)
      self.class.each_attribute(BasicAttributes::ChildReference) do |attr|
        __attr_name = attr.name
        value = if in_h[__attr_name].nil?
                  attr.default
                else
                  in_h[__attr_name]
                end

        send("make_#{__attr_name}".to_sym, value) unless value.empty?
      end
    end

    # TODO refactor the frak out of here: make generic for any ListReference
    def load_multi_reference_attributes(in_h)
      self.class.each_attribute(BasicAttributes::MultiReference) do |attr|
        __attr_name = attr.name
        value = if in_h[__attr_name].nil?
                  attr.default
                else
                  in_h[__attr_name]
                end

        value.each { |ref| send("add_#{__attr_name.to_s.singularize}".to_sym, ref) }
      end
    end

    def load_immutable_references(in_h)
      self.class.each_attribute(BasicAttributes::ImmutableReference) do |attr|
        __attr_name = attr.name
        in_value = in_h[__attr_name]
        value = case in_value
                  #FIXME We should NEVER get a Hash at this level
                  when Hash
                    Association::ImmutableEntityReference.new(in_value[:id], attr.type)
                  when Association::ImmutableEntityReference, BaseEntity, NilClass
                    in_value
                  else
                    raise IllegalArgumentException, "Invalid reference #{__attr_name}. Should be Hash or ImmutableEntityReference, is #{in_value.class}"
                end

        send("#{__attr_name}=".to_sym,value)
      end

      self.class.each_attribute(BasicAttributes::ImmutableMultiReference) do |attr|
        __attr_name = attr.name
        in_array = in_h[__attr_name]

        unless in_array.nil?
          in_array.each do |in_value|
            value = case in_value
                      #FIXME We should NEVER get a Hash at this level
                      when Hash
                        Association::ImmutableEntityReference.new(in_value[:id], attr.inner_type)
                      when Association::ImmutableEntityReference, NilClass
                        in_value
                      when BaseEntity
                        in_value.immutable
                      else
                        raise IllegalArgumentException, "Invalid reference #{__attr_name}. Should be Hash or ImmutableEntityReference, is #{in_value.class}"
                    end

            send("add_#{__attr_name.to_s.singularize}".to_sym, value)
          end
        end

        in_h.delete(__attr_name)
      end
    end

    def detach_children
      each_child do |child|
        child_attr = child.class.to_s.split('::').last.underscore.downcase.pluralize
        child.detach_parent(self)
        child.detach_children
        instance_variable_get("@#{child_attr}".to_sym).clear
      end
    end

    def detach_multi_references
      each_multi_reference do |ref, ref_attr|
        # TODO: ref.type!! See Mapper::Sequel.to_table_name
        instance_variable_get("@#{ref_attr}".to_sym).clear
      end
    end

    def detach_parent(parent_entity)
      unless self.class.parent_reference.nil?
        parent_attr = parent_entity.class.to_s.split('::').last.underscore.downcase
        if parent_entity == instance_variable_get("@#{parent_attr}".to_sym)
          instance_variable_set("@#{parent_attr}".to_sym, nil)
        else
          raise RuntimeError, "Child parent does not match"
        end
      end
    end

    def self.define_aggregate_method(plural_child_name)
      self.class_eval do

        singular_name = plural_child_name.to_s.singularize
        singular_make_method_name = "make_#{singular_name}".to_sym
        plural_make_method_name = "make_#{plural_child_name}".to_sym

        # Single-model methods:

        define_method(singular_make_method_name) do |in_h|
          child_class = self.class.attribute_descriptors[plural_child_name].inner_type
          a_child = child_class.new(in_h, self)
          send("add_#{singular_name}".to_sym, a_child)
          a_child
        end

        # Collection methods:

        define_method(plural_make_method_name) do |in_a|
          children = []
          in_a.each {|in_h| children<< send(singular_make_method_name, in_h)}
          children
        end
      end
    end

    def self.add_identifier_attributes
      super

      mutable_class = self

      self.const_get(:Immutable).class_eval do
        mutable_class.identifier_names.each do |id|
          id_var = "@#{id}".to_sym
          define_method(id){instance_variable_get(id_var)}
        end
      end
    end

    def self.attach_attribute_accessors(attribute_descriptor)
      __attr_name = attribute_descriptor.name

      if attribute_descriptor.is_attribute?
        self.const_get(:Immutable).class_eval do
          define_method(__attr_name){instance_variable_get("@#{__attr_name}".to_sym)}
        end
      end

      self.class_eval do
        define_method(__attr_name){instance_variable_get("@#{__attr_name}".to_sym)}
        singular_ref_name = __attr_name.to_s.singularize
        add_to_collection = "add_#{singular_ref_name}"

        case attribute_descriptor
          when BasicAttributes::ParentReference  # no setters here
          when BasicAttributes::ChildReference
            define_method(add_to_collection) { |new_value|
              # TODO children shouldn't have a public constructor
              attribute_descriptor.check_assignment_constraints(new_value)
              new_value._version = self._version
              instance_variable_get("@#{__attr_name}".to_sym) << new_value
            }
          when BasicAttributes::MultiReference
            define_method(add_to_collection){ |new_value|
              attribute_descriptor.check_assignment_constraints(new_value)
              instance_variable_get("@#{__attr_name}".to_sym) << new_value
            }
          when BasicAttributes::ImmutableMultiReference
            define_method(add_to_collection){ |new_value|
              attribute_descriptor.check_assignment_constraints(new_value)
              instance_variable_get("@#{__attr_name}".to_sym) << Association::ImmutableEntityReference.create(new_value)
            }
          when BasicAttributes::ImmutableReference
            define_method("#{__attr_name}="){ |new_value|
              attribute_descriptor.check_assignment_constraints(new_value)
              instance_variable_set("@#{__attr_name}".to_sym, Association::ImmutableEntityReference.create(new_value))
            }
          else
            super
        end
      end
    end

  end
end
