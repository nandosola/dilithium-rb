module BasicAttributes

  class Attribute
    attr_reader :name, :type, :default, :mandatory
    def initialize(name, type, mandatory=false, default=nil)
      # TODO validate entry
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
    attr_reader :name, :type, :reference
    def initialize(name, type=BaseEntity)
      @name = name
      @type = type
      @reference = "#{name.to_s.singularize}_id".to_sym
    end
    def check_constraints(value)  # check invariant constraints, called by setter
      raise RuntimeError, "#{@name} must be a #{@type} - got: #{value.class}" unless value.nil? || value.is_a?(@type)
    end
    def default
      nil
    end
  end

  class ValueAttribute < Attribute
  end

  class ValueReference < Reference
  end

  class ParentReference < Reference
  end

  class ChildReference < Reference
    def initialize(name)
      super(name, Array)
    end
    def default
      Array.new # pass by value
    end
  end

end