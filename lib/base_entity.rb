require 'basic_attributes'
require 'idpk'

class BaseEntity < IdPk
  extend Repository::Sequel::ClassFinders
  include Repository::Sequel::InstanceFinders
  extend UnitOfWork::TransactionRegistry::FinderService::ClassMethods
  include UnitOfWork::TransactionRegistry::FinderService::InstanceMethods

  def self.inherited(base)
    # TODO :id should be a IdentityAttribute, with a setter that prevents null assignation (à la Super layer type)
    base.class_variable_set(:'@@attributes',{PRIMARY_KEY[:identifier]=>BasicAttributes::GenericAttribute.new(
      PRIMARY_KEY[:identifier], PRIMARY_KEY[:type])})
    base.attach_attribute_accessors(PRIMARY_KEY[:identifier])

    base.class_variable_get(:'@@attributes')[:active] = BasicAttributes::GenericAttribute.new(:active,TrueClass, false, true)
    base.attach_attribute_accessors(:active)

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
      self.class_variable_get(:'@@attributes')[child] = BasicAttributes::ChildReference.new(child, self)
      self.attach_attribute_accessors(child, :list)
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
    self.class_variable_get(:'@@attributes')[parent] = BasicAttributes::ParentReference.new(parent)
    self.attach_attribute_accessors(parent, :none)
  end

  # Creates a reference to a list of BaseEntities (many-to-many)
  #
  # Example:
  #   class Department < BaseEntity
  #     multi_reference :employees, :buildings
  #
  # Params:
  # - (Symbol) *names: pluralized list of BasicEntities
  #
  def self.multi_reference(name, type = nil)
#      names.each do |reference|
#        # TODO pass type
#        self.class_variable_get(:'@@attributes')[reference] = BasicAttributes::MultiReference.new(reference, self)
#        self.attach_attribute_accessors(reference, :list)

    self.class_variable_get(:'@@attributes')[name] = BasicAttributes::MultiReference.new(name, self, type)
    self.attach_attribute_accessors(name, :list)
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
    if BaseEntity == type.superclass
      self.class_variable_get(:'@@attributes')[name] =  BasicAttributes::EntityReference.new(name, type)
    elsif BasicAttributes::GENERIC_TYPES.include?(type.superclass)
      self.class_variable_get(:'@@attributes')[name] =  BasicAttributes::ExtendedGenericAttribute.new(
        name, type, opts[:mandatory], opts[:default])
    elsif BasicAttributes::GENERIC_TYPES.include?(type)
      self.class_variable_get(:'@@attributes')[name] =  BasicAttributes::GenericAttribute.new(
        name, type, opts[:mandatory], opts[:default])
    else
      raise ArgumentError, "Cannot determine type for attribute #{name}"
    end
    self.attach_attribute_accessors(name)
  end

  def initialize(in_h={}, parent=nil)
    check_input_h(in_h)
    self.class.class_variable_get(:'@@attributes').each do |k,v|
      instance_variable_set("@#{k}".to_sym, v.default)
    end
    unless parent.nil?
      parent_attr = parent.class.to_s.split('::').last.underscore.downcase
      instance_variable_set("@#{parent_attr}".to_sym, parent)
    end
    load_attributes(in_h)
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
    if self.class.has_children?
      self.class.child_references.each do |child_attr|
        children = Array(self.send(child_attr)).clone
        children.each do |child|
          yield(child)
        end
      end
    end
  end

  def each_multi_reference
    if self.class.has_multi_references?
      self.class.multi_references.each do |ref_attr|
        references = Array(self.send(ref_attr)).clone
        references.each do |ref|
          yield(ref, ref_attr)
        end
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

  def self.parent_reference
    parent = self.get_attributes_by_type(BasicAttributes::ParentReference)
    raise RuntimeError, "found multiple parents" if 1 < parent.size
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
      unless v.empty?
        v.each do |ref|
          send("#{k}<<".to_sym, ref)
        end
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
    if self.class.has_children?
      each_child do |child|
        child_attr = child.class.to_s.split('::').last.underscore.downcase.pluralize
        child.detach_parent(self)
        child.detach_children
        instance_variable_get("@#{child_attr}".to_sym).clear
      end
    end
  end

  def detach_multi_references
    if self.class.has_multi_references?
      each_multi_reference do |ref, ref_attr|
        # TODO: ref.type!! See Mapper::Sequel.to_table_name
        instance_variable_get("@#{ref_attr}".to_sym).clear
      end
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

  def self.attach_attribute_accessors(name, type=:plain)
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

  def self.define_aggregate_method(child)
    self.class_eval do

      # Single-entity methods:

      define_method("make_#{child.to_s.singularize}".to_sym) do |in_h|
        child_class = self.class.class_variable_get(:'@@attributes')[child].inner_type
        a_child = child_class.new(in_h, self)
        send("#{child}<<".to_sym, a_child)

        a_child
      end

      # Collection methods:

      define_method("make_#{child}".to_sym) do |in_a|
        children = []
        in_a.each {|in_h| children<< send("make_#{child.to_s.singularize}".to_sym, in_h)}
        children
      end
    end
  end

end
