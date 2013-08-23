class BaseEntity
  include Mapper::Sequel
  extend Repository::Sequel::ClassFinders
  include Repository::Sequel::InstanceFinders
  extend UnitOfWork::TransactionRegistry::FinderService::ClassMethods
  include UnitOfWork::TransactionRegistry::FinderService::InstanceMethods

  attr_reader :id

  def initialize(in_h={})
    # TODO check in_h is_a? Hash
    load_attributes(in_h)
  end

  def make(in_h)
    #@metadata.mark_for_creation
    load_attributes(in_h)
  end

  def destroy
    if defined?(self.class::CHILDREN) and self.class::CHILDREN.is_a?(Array) and !self.class::CHILDREN.empty?
      self.class::CHILDREN.each do |child|
        self.send("destroy_#{child}".to_sym)
      end
    else
      #@metadata.mark_for_deletion unless @id.nil?
    end
  end

  def to_h
    h = {}
    instance_variables.each do |attr|
      attr_name = attr.to_s[1..-1].to_sym
      attr_value = instance_variable_get(attr)
      h[attr_name] =  attr_value unless attr_value.is_a?(BaseEntity) || attr_value.is_a?(Array)
    end
    h
  end

  # TODO:
  #def eql?
  #end
  #alias_method :==, :eql?

  private

  def id=(id)
    @id = id
  end

  protected

  # TODO: check_reserved_keys(in_h) => :metadata

  def load_attributes(in_h)
    if defined?(self.class::CHILDREN) and self.class::CHILDREN.is_a?(Array) and !self.class::CHILDREN.empty?
      self.class::CHILDREN.each do |child|
        initialize_attribute(child, [], :aggregate)
        self.class.define_aggregate_method(child)
        if in_h.has_key?(child)
          self.send("make_#{child}".to_sym, in_h[child])
          in_h.delete(child)
        end
      end
    end
    in_h.each do |k,v|
      unless :id == k
        initialize_attribute(k,v)
      else
        @id = v
      end
    end
  end

  def initialize_attribute(name, value=nil, type=:plain)
    instance_variable_set("@#{name}".to_sym, value)
    class << self; self; end.class_eval do
      define_method(name){instance_variable_get("@#{name}".to_sym)}
      define_method("#{name}="){ |new_value|
        instance_variable_set("@#{name}".to_sym, new_value)
      } unless :aggregate == type
    end
  end

  def self.define_aggregate_method(child)
    self.class_eval do

      # Single-entity methods:

      define_method("make_#{child.to_s.singularize}".to_sym) do |in_h|
        a_child = Object.const_get(child.to_s.singularize.camelize).new(in_h)
        a_child.send("#{self.class.to_s.split('::').last.downcase}=".to_sym, self)
        prev = self.instance_variable_get("@#{child}".to_sym)
        self.instance_variable_set("@#{child}".to_sym, prev<<a_child)
        a_child
      end

      #define_method("destroy_#{child.to_s.singularize}".to_sym) do |id=nil|
      #
      #end

      # Collection methods:

      define_method("make_#{child}".to_sym) do |in_a|
        children = []
        in_a.each {|in_h| children<< self.send("make_#{child.to_s.singularize}".to_sym, in_h)}
        children
      end

      define_method("destroy_#{child}".to_sym) do
        self.instance_variable_get("@#{child}".to_sym).each do |obj|
          obj.destroy
        end
      end
    end
  end

end