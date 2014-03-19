# -*- encoding : utf-8 -*-
module Dilithium
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
        raise ArgumentError, "#{@name} must be defined" if @mandatory && value.nil?
        if [TrueClass, FalseClass].include?(@type)
          raise ArgumentError, "#{@name} must be a boolean - got: #{value.class}" unless !!value == value
        else
          raise ArgumentError, "#{@name} must be a #{@type} - got: #{value.class}" unless value.nil? || value.is_a?(@type)
        end
      end

      def generic_type
        type
      end

      def to_generic_type(value)
        value
      end
    end

    class Reference
      attr_reader :name, :type

      def initialize(name, klazz)
        @name = name
        @type = klazz
      end

      def check_constraints(value)   # check invariant constraints, called by check_input_h
        raise RuntimeError, "#{@name} must be a #{@type} - got: #{value.class}" unless
          value.nil? ||
            value.is_a?(@type) ||
            (value.is_a?(Association::LazyEntityReference) && value._type <= @type)
      end

      def check_assignment_constraints(value) # check invariant constraints, called by setter
        check_constraints(value)
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

      def self.path_to_class(path)
        path.reduce(Object){ |m,c| m.const_get(c) }
      end
    end

    class ListReference < Reference
      def initialize(name, containing_class, type=nil)
        super(name, Array)

        @reference_path = if type.nil?
                            Reference.get_reference_path(containing_class, name)
                          else
                            type.to_s.split('::')
                          end
      end

      def default
        Array.new # pass by value
      end

      def inner_type
        @inner_type ||= Reference.path_to_class(@reference_path)
      end

      def reference_path
        Array.new(@reference_path)
      end

      def check_assignment_constraints(value)  # check invariant constraints, called by setter
        raise RuntimeError, "#{@name} must contain only elements of type #{inner_type} - got: #{value.class}" unless
          value.nil? ||
            value.is_a?(inner_type) ||
            (value.is_a?(Association::LazyEntityReference) && value._type <= inner_type)
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

      def generic_type
        type.superclass
      end

      def to_generic_type(value)
        case value
          when String
            value.to_s
          when Integer
            value.to_i
          when Float
            value.to_f
        end
      end


    end

    class ParentReference < Reference
      def initialize(parent_name, child_klazz)
        reference_path = Reference.get_reference_path(child_klazz, parent_name)
        parent_klazz = Reference.path_to_class(reference_path)
        super(parent_name, parent_klazz)
      end
    end

    class ChildReference < ListReference
    end

    class MultiReference < ListReference
    end

    class ImmutableReference < Reference
      def check_constraints(value)
        raise ArgumentError, "Reference to #{@name} must be a #{@type} - got: #{value.class}" unless
          case value
            when Association::ImmutableEntityReference
              value._type <= @type
            when Hash
              value.include?(:id)
            when BaseEntity, NilClass
              true
            else
              false
          end
      end
    end

    class ImmutableMultiReference < MultiReference
      def check_assignment_constraints(value)  # check invariant constraints, called by setter
        path = value.class.to_s.split('::').map{|c| c.to_sym}

        clazz = if path.last == :Immutable
                  Reference.path_to_class(path[0..-2])
                else
                  value.class
                end
        raise RuntimeError, "#{@name} must contain only elements of type #{inner_type} - got: #{value.class}" unless
          value.nil? ||
            clazz <= inner_type ||
            (value.is_a?(Association::LazyEntityReference) && value._type <= inner_type)
      end
    end
  end
end
