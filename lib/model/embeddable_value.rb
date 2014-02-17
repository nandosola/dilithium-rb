# -*- encoding : utf-8 -*-
module Dilithium
  module EmbeddableValue
    include BaseMethods

    #TODO Implement BaseValue (and the embed method in BaseMethods) which would be an actual class
    #TODO Implement eql? and == to do value comparisons

    def self.extended(base_value)
      base_value.instance_eval do
        def included(base_entity)
          raise ArgumentError, 'EmbeddabelValue should only be mixed into BaseEntities' unless base_entity < BaseEntity
          @attributes.values.each { |desc| base_entity.add_attribute(desc) }
        end

        def add_attribute(descriptor)
          raise ArgumentError, "Duplicate definition for #{name}" if @attributes.has_key?(name)
          @attributes[descriptor.name] = descriptor
        end

        @attributes = { }
      end
    end
  end
end