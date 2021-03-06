# -*- encoding : utf-8 -*-

module Dilithium
  module ValueMapper
    module Sequel
      extend DefaultMapper::Sequel

      self.singleton_class.send(:alias_method, :__insert, :insert)
      def self.insert(domain_object, parent_id = nil)
        klazz = domain_object.class
        phantom_id = IntegerSequence.get_next(domain_object)
        domain_object._phantomid = phantom_id.to_i if klazz.include?(PhantomIdentifier)

        unless Dilithium::Repository.for(klazz).exists?(domain_object)
          __insert(domain_object, parent_id)
        else
          # Constraint violations on multiple keys get mapped as generic Sequel::DatabaseErrors.
          # This exception prevents the API user from relying too much on native DB exceptions
          # See https://github.com/jeremyevans/sequel/issues/782
          raise Dilithium::PersistenceExceptions::ValueAlreadyExistsError
        end
      end

      def self.update(domain_object)
        raise Dilithium::PersistenceExceptions::ImmutableObjectError, "#{domain_object.class} is immutable - it can't be updated"
      end

    end
  end
end