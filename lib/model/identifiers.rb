# -*- encoding : utf-8 -*-
require 'observer'

module Dilithium
  module Identifiers
    module Id

      def self.extended(base)
        base.class_eval do
          include Observable
        end
        base.const_set(:IDENTIFIERS, [{:identifier => :id, :type => Integer}])
      end

      def identifiers
        const_get :IDENTIFIERS
      end

      def identifier_names
        identifiers.map { |h| h[:identifier] }
      end

      def add_identifier_accessors
        identifiers.each do |id_desc|
          id = id_desc[:identifier]
          id_type = id_desc[:type]

          @attributes[id] = BasicAttributes::GenericAttribute.new(id, id_type) unless attribute_descriptors.key? id
        end

        self.class_eval do
          self.const_get(:Immutable).class_eval do
            mutable_class = const_get(:MUTABLE_CLASS)

            mutable_class.identifier_names.each do |id|
              id_var = "@#{id}".to_sym
              define_method(id) { instance_variable_get(id_var) }
            end
          end

          identifier_names.each do |id|
            id_var = "@#{id}".to_sym
            define_method(id){instance_variable_get(id_var)}
          end

          # TODO Should this be a new class (IdentityAttribute)?
          identifiers.each do |id_desc|
            id = id_desc[:identifier]

            define_method("#{id}=") do |new_value|
              id_name = :"@#{id}"
              old_value = instance_variable_get(id_name)

              #FIXME This should be removed once we clean up load_attributes/full_update
              return if old_value == new_value

              raise ArgumentError, "Can't reset #{self.class} ID once it has been set. Old value = #{old_value}, new value = #{new_value}" unless old_value.nil?
              raise ArgumentError, "ID must be a #{id_desc[:type]}. It can't be a #{new_value.class}" unless new_value.is_a?(id_desc[:type])

              instance_variable_set(id_name, new_value)
              changed
              notify_observers(self, id, new_value)
            end
          end
        end
      end
    end
  end
end