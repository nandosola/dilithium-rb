# -*- encoding : utf-8 -*-
module Dilithium
  module EmbeddableValue
    include BaseMethods::Attributes
    include BaseMethods::References

    #TODO Implement BaseValue (and the embed method in BaseMethods) which would be an actual class
    #TODO Implement eql? and == to do value comparisons

    def self.extended(base)
      base.instance_eval do

        # TODO Move this into BaseMethods::Attributes
        @attributes = { }

        # EmbeddableValue only stores the attribute descriptors: values (and accessors) are stored in the including BaseEntity
        def included(embedding_class)
          raise ArgumentError, 'EmbeddableValue should only be mixed into DomainObjects' unless embedding_class < DomainObject
          @attributes.values.each { |desc| embedding_class.add_attribute(desc) }
        end
      end
    end
  end
end