module Dilithium
# Layer Super-Type that handles only identifier and attributes for immutable classes. No references of any kind.
  class ImmutableDomainObject < DomainObject
    def self.attach_attribute_accessors(attribute_descriptor)
      __attr_name = attribute_descriptor.name

      self.class_eval do
        var_name = "@#{__attr_name}".to_sym

        define_method(__attr_name){instance_variable_get(var_name)}

        #TODO See comments for Issue #49: It should really not have mutators but they are needed to load data initially
        define_method("#{__attr_name}="){ |new_value|
          attribute_descriptor.check_constraints(new_value)
          if instance_variable_get(var_name).nil?
            instance_variable_set(var_name, new_value)
          else
            raise Dilithium::DomainObjectExceptions::ImmutableError, "The value of #{__attr_name} cannot be changed has been set"
          end
        }
      end
    end

  end
end
