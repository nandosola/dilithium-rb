require 'basic_attributes'
require 'idpk'

class BaseEntity < IdPk
  extend Repository::Sequel::ClassFinders
  include Repository::Sequel::InstanceFinders
  extend UnitOfWork::TransactionRegistry::FinderService::ClassMethods
  include UnitOfWork::TransactionRegistry::FinderService::InstanceMethods

  # Each BaseEntity subclass will have an internal class called Immutable that contains the immutable representation of
  # said BaseEntity. The Immutable classes are all subclasses of BaseEntity::Immutable
  class Immutable
  end

  def self.inherited(base)
    # Create the internal Immutable class for this BaseEntity
    base.const_set(:Immutable, Class.new(BaseEntity::Immutable))

    # TODO :id should be a IdentityAttribute, with a setter that prevents null assignation (à la Super layer type)
    descriptor = BasicAttributes::GenericAttribute.new(PRIMARY_KEY[:identifier], PRIMARY_KEY[:type])
    base.class_variable_set(:'@@attributes', { PRIMARY_KEY[:identifier]=> descriptor })
    base.attach_attribute_accessors(PRIMARY_KEY[:identifier], :plain, descriptor)

    descriptor = BasicAttributes::GenericAttribute.new(:active,TrueClass, false, true)
    base.class_variable_get(:'@@attributes')[:active] = descriptor
    base.attach_attribute_accessors(:active, :plain, :descriptor)

    base.instance_eval do
      def attributes
        #TODO return the whole attr array
        self.class_variable_get(:'@@attributes').values
      end
    end
  end

  # Adds children to the current entity acting as aggregate root.
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
      descriptor = BasicAttributes::ChildReference.new(child, self)
      self.class_variable_get(:'@@attributes')[child] = descriptor
      self.attach_attribute_accessors(child, :list, descriptor)
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
    # TODO pass type
    descriptor = BasicAttributes::ParentReference.new(parent, self)
    self.class_variable_get(:'@@attributes')[parent] = descriptor
    self.attach_attribute_accessors(parent, :none, descriptor)
  end

  # Creates a reference to a list of BaseEntities (many-to-many).
  #
  # Example:
  #   class Department < BaseEntity
  #     multi_reference :employees
  #     multi_reference :buildings
  #     multi_reference :sub_departments, Department
  #
  # Params:
  # - (Symbol) name: name of the attribute. If no type is provided, will be treated as a pluralized name of a BaseEntity
  # - (BaseEntity) type: type of the BaseEntity this reference holds. If not supplied will be inferred from name.
  #
  def self.multi_reference(name, type = nil)
    descriptor = BasicAttributes::MultiReference.new(name, self, type)
    self.class_variable_get(:'@@attributes')[name] = descriptor
    self.attach_attribute_accessors(name, :list, descriptor)
  end

  # Creates an attribute or a reference to a single BasicEntity (many-to-one). The attribute must extend BaseEntity,
  # any Ruby Generic type (except for Enumerable) or be a generic type itself.
  #
  # Example:
  #   attribute :desc, String, mandatory:true, default:'foo'
  #   attribute :country, CountryEntity
  #   attribute :password, BCrypt::Password
  #
  # Params:
  # - name: attribute name
  # - type: atrribute class
  # - opts: hash with options(only for attribute)
  #     * mandatory: true or false,
  #     * default: default value
  #
  def self.attribute(name, type, opts = {})
    descriptor = if BaseEntity == type.superclass
                   BasicAttributes::EntityReference.new(name, type)
                 elsif BasicAttributes::GENERIC_TYPES.include?(type.superclass)
                   BasicAttributes::ExtendedGenericAttribute.new(name, type, opts[:mandatory], opts[:default])
                 elsif BasicAttributes::GENERIC_TYPES.include?(type)
                   BasicAttributes::GenericAttribute.new(name, type, opts[:mandatory], opts[:default])
                 else
                   raise ArgumentError, "Cannot determine type for attribute #{name}"
                 end

    self.class_variable_get(:'@@attributes')[name] = descriptor

    self.attach_attribute_accessors(name, :plain, descriptor)
  end

  def initialize(in_h={}, parent=nil)
    check_input_h(in_h)
    self.class.class_variable_get(:'@@attributes').each do |k,v|
      instance_variable_set("@#{k}".to_sym, v.default)
    end
    unless parent.nil?
      parent_attr = parent.type.to_s.split('::').last.underscore.downcase
      instance_variable_set("@#{parent_attr}".to_sym, parent)
    end
    load_attributes(in_h)
  end

  def type
    self.class
  end

  def full_update(in_h)
    raise ArgumentError, "Entity id must be defined and not changed" if id != in_h[PRIMARY_KEY[:identifier]]
    check_input_h(in_h)
    detach_children
    detach_multi_references
    load_attributes(in_h)
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

  def each_multi_reference
    self.class.multi_references.each do |ref_attr|
      references = Array(self.send(ref_attr)).clone
      references.each do |ref|
        yield(ref, ref_attr)
      end
    end
  end

  def each_entity_reference
    self.class.entity_references.each do |ref_attr|
      references = Array(self.send(ref_attr)).clone
      references.each do |ref|
        yield(ref, ref_attr)
      end
    end
  end

  def find_child
    each_child do |child|
      return child if yield(child)
    end
    nil
  end

  def find_multi_reference
    each_multi_reference do |ref, ref_attr|
      return ref if yield(ref, ref_attr)
    end
    nil
  end

  def find_entity_reference
    each_entity_reference do |ref, ref_attr|
      return ref if yield(ref, ref_attr)
    end
    nil
  end

  # Return an immutable copy of this object. The immutable copy will be disconnected from its parent and children and
  # any references (i.e., it will contain only GenericAttributes and ExtendedGenericAttributes). If you need to get
  # a reference you need to use a Finder in the entity's Root to get the Entity and from there get the reference.
  def immutable
    obj = self.class.const_get(:Immutable).new
    attributes = self.class.class_variable_get(:'@@attributes')

    attributes.each do |name, attr|
      if attr.is_a?(BasicAttributes::GenericAttribute)
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

  def self.child_references
    self.get_attributes_by_type(BasicAttributes::ChildReference)
  end

  def self.multi_references
    self.get_attributes_by_type(BasicAttributes::MultiReference)  # TODO: Rename to MultiReference
  end

  def self.entity_references
    self.get_attributes_by_type(BasicAttributes::EntityReference)
  end

  def self.extended_generic_attributes
    self.get_attributes_by_type(BasicAttributes::ExtendedGenericAttribute)
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

  def self.has_entity_references?
    !self.entity_references.empty?
  end

  def self.has_extended_generic_attributes?
    !self.extended_generic_attributes.empty?
  end

  private
  protected

  def check_input_h(in_h)
    raise ArgumentError, "BaseEntity must be initialized with a Hash - got: #{in_h.class}" unless in_h.is_a?(Hash)
    unless in_h.empty?
      # TODO: check_reserved_keys(in_h) => :metadata
      attributes = self.class.class_variable_get(:'@@attributes')
      attr_keys = attributes.keys
      in_h.each do |k,v|
        raise ArgumentError, "Attribute #{k} is not allowed in #{self.class}" unless attr_keys.include?(k)
        attributes[k].check_constraints(v)
      end
    end
  end

  def load_attributes(in_h)
    unless in_h.empty?
      load_self_attributes(in_h)
      load_child_attributes(in_h)
      load_multi_reference_attributes(in_h)
    end
  end

  def load_child_attributes(in_h)
    aggregates = {}
    self.class.attributes.each do |attr|
      if [BasicAttributes::ChildReference].include?(attr.class)
        aggregates[attr.name] = unless in_h[attr.name].nil?
                                  in_h[attr.name]
                                else
                                  attr.default
                                end
      end
    end

    (aggregates.each do |k,v|
      send("make_#{k}".to_sym, v) unless v.empty?
    end) unless aggregates.empty?
  end

  # TODO refactor the frak out of here: make generic for any ListReference
  def load_multi_reference_attributes(in_h)
    references = {}
    self.class.attributes.each do |attr|
      if [BasicAttributes::MultiReference].include?(attr.class)
        references[attr.name] = unless in_h[attr.name].nil?
                                  in_h[attr.name]
                                else
                                  attr.default
                                end
      end
    end

    # TODO refactor to collection_accessor (add_{plural} -> add_{singular} -> <<)
    (references.each do |k,v|
      v.each do |ref|
        send("#{k}<<".to_sym, ref)
      end
    end) unless references.empty?
  end

  def load_self_attributes(in_h)
    self.class.attributes.each do |attr|
      if [BasicAttributes::GenericAttribute, BasicAttributes::ExtendedGenericAttribute,
          BasicAttributes::EntityReference].include?(attr.class)
        value = if in_h.include?(attr.name)
                  in_h[attr.name]
                else
                  attr.default
                end
        send("#{attr.name}=".to_sym,value)
        in_h.delete(attr.name)
      end
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

  def self.get_attributes_by_type(type)
    attrs = self.attributes
    refs = attrs.reduce([]){|m,attr| attr.instance_of?(type) ? m<<attr.name : m }
    refs
  end

  #TODO Remove type parameter, infer from attribute_descriptor
  def self.attach_attribute_accessors(name, type, attribute_descriptor)
    if attribute_descriptor.is_a? BasicAttributes::GenericAttribute
      self.const_get(:Immutable).class_eval do
        define_method(name){instance_variable_get("@#{name}".to_sym)}
      end
    end

    self.class_eval do
      define_method(name){instance_variable_get("@#{name}".to_sym)}
      if :plain == type
        define_method("#{name}="){ |new_value|
          self.class.class_variable_get(:'@@attributes')[name].check_constraints(new_value)
          instance_variable_set("@#{name}".to_sym, new_value)
        }
      elsif :list == type
        define_method("#{name}<<"){ |new_value|
          instance_variable_get("@#{name}".to_sym)<< new_value
        }
      end
    end
  end

  def self.define_aggregate_method(plural_child_name)
    self.class_eval do

      singular_name = plural_child_name.to_s.singularize
      singular_make_method_name = "make_#{singular_name}".to_sym
      plural_make_method_name = "make_#{plural_child_name}".to_sym
      plural_add_method_name = "#{plural_child_name}<<".to_sym

      # Single-entity methods:

      define_method(singular_make_method_name) do |in_h|
        child_class = self.class.class_variable_get(:'@@attributes')[plural_child_name].inner_type
        a_child = child_class.new(in_h, self)
        send(plural_add_method_name, a_child)

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

end
