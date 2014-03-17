# -*- encoding : utf-8 -*-
module Dilithium
  module EmbeddableValue
    include BaseMethods::Attributes
    include BaseMethods::References

    #TODO Implement BaseValue (and the embed method in BaseMethods) which would be an actual class
    #TODO Implement eql? and == to do value comparisons

    def self.extended(base_value)
      base_value.instance_eval do

        # TODO Move this into BaseMethods::Attributes
        @attributes = { }

        # EmbeddableValue only stores the attribute descriptors: values (and accessors) are stored in the including BaseEntity
        def included(base_entity)
          raise ArgumentError, 'EmbeddabelValue should only be mixed into BaseEntities' unless base_entity < BaseEntity
          @attributes.values.each { |desc| base_entity.add_attribute(desc) }
        end
      end
    end
  end
end