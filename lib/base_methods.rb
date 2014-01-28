# Common methods for BaseEntity and EmbeddableValue
module BaseMethods
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
  def multi_reference(name, type = nil)
    self.add_attribute(BasicAttributes::MultiReference.new(name, self, type))
  end

  # Creates an attribute. The attribute must extend Ruby Generic type (except for Enumerable) or be a generic type
  # itself.
  #
  # Example:
  #   attribute :desc, String, mandatory:true, default:'foo'
  #   attribute :password, BCrypt::Password
  #
  # Params:
  # - name: attribute name
  # - type: atrribute class
  # - opts: hash with options(only for attribute)
  #     * mandatory: true or false,
  #     * default: default value
  #
  def attribute(name, type, opts = {})
    raise ArgumentError, "Attribute #{name} is a BaseEntity. Use reference instead of attribute" if self.is_a_base_entity?(type)
    descriptor = if BasicAttributes::GENERIC_TYPES.include?(type.superclass)
                   BasicAttributes::ExtendedGenericAttribute.new(name, type, opts[:mandatory], opts[:default])
                 elsif BasicAttributes::GENERIC_TYPES.include?(type)
                   BasicAttributes::GenericAttribute.new(name, type, opts[:mandatory], opts[:default])
                 else
                   raise ArgumentError, "Cannot determine type for attribute #{name}"
                 end

    self.add_attribute(descriptor)
  end

  # Creates an immutable reference to a BaseEntity or multiple BaseEntities in a different root.
  #
  # Example:
  #   reference :owner, Department
  #   reference :departments, Department, :multi => true
  #
  # Params:
  # - name: attribute name
  # - type: atrribute class
  #
  def reference(name, type, opts = {})
    raise ArgumentError, 'Attributes should only be primitive types' unless is_a_base_entity?(type)
    attr = if opts[:multi]
             BasicAttributes::ImmutableMultiReference.new(name, self, type)
           else
             BasicAttributes::ImmutableReference.new(name, type)
           end

    self.add_attribute(attr)
  end

  def is_a_base_entity?(type)
    if type == BaseEntity
      true
    elsif type == Object
      false
    else
      self.is_a_base_entity?(type.superclass)
    end
  end

end