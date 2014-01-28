module BasicAttributes

  GENERIC_TYPES = [String, Integer, Float, DateTime, TrueClass, FalseClass]

  class GenericAttribute
    attr_reader :name, :type, :default, :mandatory
    def initialize(name, type, mandatory=false, default=nil)
      raise ArgumentError, "The attribute #{name} is not a Ruby generic type" unless \
       BasicAttributes::GENERIC_TYPES.include?(type)
      @name = name
      @type = type
      @mandatory = mandatory
      @default = default
    end
    def check_constraints(value)  # check invariant constraints, called by setter
      raise RuntimeError, "#{@name} must be defined" if @mandatory && value.nil?
      if [TrueClass, FalseClass].include?(@type)
        raise RuntimeError, "#{@name} must be a boolean - got: #{value.class}" unless !!value == value
      else
        raise RuntimeError, "#{@name} must be a #{@type} - got: #{value.class}" unless value.nil? || value.is_a?(@type)
      end
    end
  end

  class Reference
    attr_reader :name, :type
    def initialize(name, klazz)
      @name = name
      @type = klazz
    end
    def check_constraints(value)  # check invariant constraints, called by setter
      raise RuntimeError, "#{@name} must be a #{@type} - got: #{value.class}" unless
        value.nil? ||
          value.is_a?(@type) ||
          (value.is_a?(Association::LazyEntityReference) && value.type <= @type)
    end
    def default
      nil
    end
    protected
    def self.get_reference_path(clazz, attr_name)
      module_path = clazz.to_s.split('::')
      reference_literal = attr_name.to_s.singularize.camelize
      module_path.pop
      module_path.push(reference_literal)
    end
  end

  class ListReference < Reference
    def initialize(name, containing_class, type=nil)
      super(name, Array)
      if type.nil?
        @reference_path = Reference.get_reference_path(containing_class, name)
      else
        @reference_path = type.to_s.split('::')
      end
    end
    def default
      Array.new # pass by value
    end
    def inner_type
      @reference_path.reduce(Object){ |m,c| m.const_get(c) }
    end
    def reference_path
      Array.new(@reference_path)
    end
  end

  class ExtendedGenericAttribute < GenericAttribute
    def initialize(name, type, mandatory=false, default=nil)
      raise ArgumentError, "The attribute #{name} does not extend a Ruby generic type" unless \
       BasicAttributes::GENERIC_TYPES.include?(type.superclass)
      @name = name
      @type = type
      @mandatory = mandatory
      @default = default  # TODO extra check for default value type
    end
    def to_generic_type(attr)
      case attr
        when String
          attr.to_s
        when Integer
          attr.to_i
        when Float
          attr.to_f
      end
    end
  end

  class Version < Reference
  end

  class ParentReference < Reference
    def initialize(parent_name, child_klazz)
      reference_path = Reference.get_reference_path(child_klazz, parent_name)
      parent_klazz = reference_path.reduce(Object){ |m,c| m.const_get(c) }
      super(parent_name, parent_klazz)
    end
  end

  class ChildReference < ListReference
  end

  class MultiReference < ListReference
  end

  class ImmutableReference < Reference
    def check_constraints(value)
      raise RuntimeError, "Reference to #{@name} must be a #{@type} - got: #{value.class}" unless
        case value
          when Association::ImmutableEntityReference
            value.type <= @type
          when Hash
            value.include?(:id)
          when BaseEntity, NilClass
            true
          else
            false
        end
    end
  end

  class ImmutableMultiReference < ListReference
  end
end