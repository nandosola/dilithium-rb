# -*- encoding : utf-8 -*-
module Dilithium
  module EmbeddableValue
    include BaseMethods::Attributes
    include BaseMethods::References

    #TODO Implement BaseValue (and the embed method in BaseMethods) which would be an actual class
    #TODO Implement eql? and == to do value comparisons

    def self.extended(base_value)
      base_value.instance_eval do
        def included(base_entity)
          raise ArgumentError, 'EmbeddabelValue should only be mixed into BaseEntities' unless base_entity < BaseEntity
          @attributes.values.each { |desc| base_entity.add_attribute(desc) }
        end

        def add_attribute(descriptor)
          __attr_name = descriptor.name
          raise ArgumentError, "Duplicate definition for #{__attr_name}" if @attributes.has_key?(__attr_name)
          @attributes[__attr_name] = descriptor
        end

        @attributes = { }
      end
    end
  end
end