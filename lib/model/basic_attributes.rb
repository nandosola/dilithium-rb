# -*- encoding : utf-8 -*-
module Dilithium
  module BasicAttributes

    GENERIC_TYPES = [String, Integer, Float, BigDecimal, DateTime, TrueClass, FalseClass]

    # Numerics in Ruby are immediates, meaning that they don't represent
    # a heap-allocated object. Since you can’t allocate them, you can’t
    # create a subclass and allocate instances of the subclass.
    # See: http://devblog.avdi.org/2011/08/17/you-cant-subclass-integers-in-ruby/

    # This is a proxy object so that end users can "subclass" Integers.
    # CAVEAT: Case equality with Integer will *never* be satisfied w/o monkeypatching Integer itself.
    # Before using a WrappedInteger inside a 'case' clause, please coerce it to Integer using #to_i
    class WrappedInteger < BasicObject

      def initialize(integer)
        raise ArgumentError, "This constructor takes an Integer" unless integer.class < ::Integer
        @value = integer
      end

      def to_i
        @value
      end
      alias_method :to_int, :to_i

      def ==(other)
        @value == other.to_i
      end

      def respond_to?(method)
        super or @value.respond_to?(method)
      end

      def method_missing(m, *args, &b)
        super unless @value.respond_to?(m)

        unwrapped_args = args.collect do |arg|
          arg.is_a?(::Dilithium::BasicAttributes::WrappedInteger) ? arg.to_i : arg
        end

        ret = @value.send(m, *unwrapped_args, &b)

        return ret if :coerce == m

        if ret.is_a?(::Integer)
          ::Dilithium::BasicAttributes::WrappedInteger.new(ret)
        elsif ret.is_a?(::Array)
          ret.collect do |element|
            element.is_a?(::Integer) ? ::Dilithium::BasicAttributes::WrappedInteger.new(element) : element
          end
        else
          ret
        end
      end
    end

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

      def is_attribute?
        true
      end
    end

    class ExtendedGenericAttribute < GenericAttribute
      def initialize(name, type, mandatory=false, default=nil)
        raise ArgumentError, "The attribute #{name} does not extend a Ruby generic type" unless
            ExtendedGenericAttribute.extends_generic_type?(type)
        @name = name
        @type = type
        @mandatory = mandatory
        @default = default  # TODO extra check for default value type
      end

      def self.extends_generic_type?(type)
        (GENERIC_TYPES + [::Dilithium::BasicAttributes::WrappedInteger]).include?(type.superclass)
      end

      def check_constraints(value)
        unless @type < ::Dilithium::BasicAttributes::WrappedInteger
          super
        else
          raise ArgumentError, "#{@name} must be an Integer - got: #{value.class}" unless value.nil? || value.is_a?(Integer)
        end
      end

      def generic_type
        type.superclass
      end

      def to_generic_type(value)
        case value
          when String
            value.to_s
          when Integer, ::Dilithium::BasicAttributes::WrappedInteger
            value.to_i
          when Float
            value.to_f
        end
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

      def is_attribute?
        false
      end

    end

    class ValueReference < Reference
      def initialize(name, type, mandatory = false, default = nil)
        super(name, type)
      end

      def check_constraints(value)
        # no-op
      end

      def is_attribute?
        true
      end
    end

    class ListReference < Reference
      def initialize(name, containing_class, type=nil)
        super(name, Array)
        @reference_namespace = type.nil? ? containing_class.ns.append_to_module_path(name) : type.ns.full_path
      end

      def default
        Array.new # pass by value
      end

      def inner_type
        @inner_type ||= @reference_namespace.to_class
      end

      def reference_path
        Array.new(@reference_namespace.to_a)
      end

      def check_assignment_constraints(value)  # check invariant constraints, called by setter
        raise RuntimeError, "#{@name} must contain only elements of type #{inner_type} - got: #{value.class}" unless
          value.nil? ||
            value.is_a?(inner_type) ||
            (value.is_a?(Association::LazyEntityReference) && value._type <= inner_type)
      end
    end

    class ParentReference < Reference
      def initialize(parent_name, child_klazz)
        parent_klazz = child_klazz.ns.append_to_module_path(parent_name, true)
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

        ns = value._type.ns
        full_path = ns.full_path
        container_path = ns.module_path

        clazz = if full_path.to_a.last.to_sym == :Immutable
                  # FIXME this code has no tests:
                  container_path.to_class
                else
                  value._type
                end
        raise RuntimeError, "#{@name} must contain only elements of type #{inner_type} - got: #{value.class}" unless
          value.nil? ||
            clazz <= inner_type ||
            (value.is_a?(Association::LazyEntityReference) && value._type <= inner_type)
      end
    end
  end
end
