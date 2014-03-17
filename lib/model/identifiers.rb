# -*- encoding : utf-8 -*-
require 'observer'

module Dilithium
  module Identifiers
    module Id

      def self.extended(base)
        base.class_eval do
          include Observable
        end
        base.const_set(:IDENTIFIER, {:identifier => :id, :type => Integer})
      end

      def identifiers
        const_get :IDENTIFIER
      end

      def identifier_names
        identifiers[:identifier]
      end

      def add_identifier_accessors
        @attributes[identifier_names] = BasicAttributes::GenericAttribute.new(identifier_names, identifiers[:type]) unless attribute_descriptors.has_key? identifier_names

        self.class_eval do
          self.const_get(:Immutable).class_eval do
            mutable_class = const_get(:MUTABLE_CLASS)
            define_method(mutable_class.identifier_names){instance_variable_get("@#{mutable_class.identifier_names}".to_sym)}
          end

          define_method(identifier_names){instance_variable_get("@#{self.class.identifier_names}".to_sym)}

          # TODO Should this be a new class (IdentityAttribute)?
          define_method("#{identifier_names}="){ |new_value|
            id_name = "@#{self.class.identifier_names}".to_sym
            old_value = instance_variable_get(id_name)

            #FIXME This should be removed once we clean up load_attributes/full_update
            return if old_value == new_value

            raise ArgumentError, "Can't reset #{self.class} ID once it has been set. Old value = #{old_value}, new value = #{new_value}" unless old_value.nil?
            raise ArgumentError, "ID must be a #{self.class.identifiers[:type]}. It can't be a #{new_value.class}" unless new_value.is_a?(self.class.identifiers[:type])

            instance_variable_set(id_name, new_value)
            changed
            notify_observers(self, self.class.identifier_names, new_value)
          }
        end
      end


    end
  end
end