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
      if [TrueClass, FalseClass].include?@type
        raise RuntimeError, "#{@name} must be a boolean - got: #{value.class}" unless !!value == value
      else
        raise RuntimeError, "#{@name} must be a #{@type} - got: #{value.class}" unless value.nil? || value.is_a?(@type)
      end
    end
  end

  class Reference
    attr_reader :name, :type
    def initialize(name, type=BaseEntity)
      @name = name
      @type = type
    end
    def check_constraints(value)  # check invariant constraints, called by setter
      raise RuntimeError, "#{@name} must be a #{@type} - got: #{value.class}" unless
        value.nil? || value.is_a?(@type) || (value.is_a?(Association::ReferenceEntity) && value.type <= @type)
      # check_reference_active
    end
    def default
      nil
    end
  end

  class ListReference < Reference
    def initialize(name, containing_class, type = nil)
      super(name, Array)
      module_path = containing_class.to_s.split('::')
      if type.nil?
        reference_literal = name.to_s.singularize.camelize
        @reference_path = if 1 == module_path.size
                            [reference_literal]
                          elsif 1 < module_path.size
                            module_path[0..-2] << reference_literal
                          else
                            raise RuntimeError, "Cannot determine #{reference_literal} namespace for parent path #{module_path.join('::')}"
                          end
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

  class EntityReference < Reference
  end

  class ParentReference < Reference
  end

  class ChildReference < ListReference
  end

  class MultiReference < ListReference
  end


end