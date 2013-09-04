require 'basic_attributes'

class IdPk
  PRIMARY_KEY = {:identifier=>:id, :type=>Integer}

  def self.pk
    PRIMARY_KEY[:identifier]
  end
end

class BaseEntity < IdPk
  extend Repository::Sequel::ClassFinders
  include Repository::Sequel::InstanceFinders
  extend UnitOfWork::TransactionRegistry::FinderService::ClassMethods
  include UnitOfWork::TransactionRegistry::FinderService::InstanceMethods

  def self.inherited(base)
    # TODO :id should be a IdentityAttribute, with a setter that prevents null assignation (à la Super layer type)
    base.class_variable_set(:'@@attributes',{PRIMARY_KEY[:identifier]=>BasicAttributes::Attribute.new(
        PRIMARY_KEY[:identifier], PRIMARY_KEY[:type])})
    base.attach_attribute_accessors(PRIMARY_KEY[:identifier])

    base.class_variable_get(:'@@attributes')[:active] = BasicAttributes::Attribute.new(:active,TrueClass, false, true)
    base.attach_attribute_accessors(:active)

    base.instance_eval do
      def attributes
        self.class_variable_get(:'@@attributes').values
      end
    end
  end

  def self.children(*names)
    names.each do |child|
      self.class_variable_get(:'@@attributes')[child] = BasicAttributes::ChildReference.new(child)
      self.attach_attribute_accessors(child, :aggregate)
      self.define_aggregate_method(child)
    end
  end

  def self.parent(parent)
    self.class_variable_get(:'@@attributes')[parent] = BasicAttributes::ParentReference.new(parent)
    self.attach_attribute_accessors(parent, :parent)
  end

  def self.attribute(name, type, *opts)
    parsed_opts = opts.reduce({}){|m,opt| m.merge!(opt); m }
    if BaseEntity == type.superclass
      self.class_variable_get(:'@@attributes')[name] =  BasicAttributes::ValueReference.new(name, type)
    else
      self.class_variable_get(:'@@attributes')[name] =  BasicAttributes::Attribute.new(
          name, type, parsed_opts[:mandatory], parsed_opts[:default])
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
    check_input_h(in_h)
    detach_children
    load_attributes(in_h)
  end

  def make(in_h)
    check_input_h(in_h)
    load_attributes(in_h)
  end

  # Executes a proc for each child, passing child as parameter to proc
  def each_child
    if self.class.has_children?
      self.class.child_references.each do |children_type|
        children = Array(self.send(children_type))
        children.each do |child|
          yield(child)
        end
      end
    end
  end

  def self.parent_reference
    parent = self.get_references(BasicAttributes::ParentReference)
    raise RuntimeError, "found multiple parents" if 1 < parent.size
    parent.first
  end
  
  def self.child_references
    self.get_references(BasicAttributes::ChildReference)
  end

  def self.value_references
    self.get_references(BasicAttributes::ValueReference)
  end

  def self.has_children?
    !self.child_references.empty?
  end
  
  def self.has_value_references?
    !self.value_references.empty?
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
      load_root_attributes(in_h)
      load_child_attributes(in_h)
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
      send("make_#{k}".to_sym, v)
    end) unless aggregates.empty?
  end

  def load_root_attributes(in_h)
    self.class.attributes.each do |attr|
      if [BasicAttributes::Attribute, BasicAttributes::ValueReference].include?(attr.class)
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
        instance_variable_get("@#{child_attr}".to_sym).delete_if{|x| child == x}
        child.detach_parent(self)
        child.detach_children
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

  def self.get_references(type)
    attrs = self.attributes
    refs = attrs.reduce([]){|m,attr| attr.is_a?(type) ? m<<attr.name : m }
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
      elsif :aggregate == type
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
        a_child = Object.const_get(child.to_s.singularize.camelize).new(in_h, self)
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
