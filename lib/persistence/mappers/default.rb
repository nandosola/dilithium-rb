# -*- encoding : utf-8 -*-

module Dilithium

  module Mapper

    def self.for(entity_class)
      if entity_class < ::Dilithium::BaseValue
        ValueMapper::Sequel
      elsif entity_class < ::Dilithium::BaseEntity
        EntityMapper::Sequel
      else
        raise RuntimeError.new("Unknown class for Mapper")
      end
    end

  end


  module DefaultMapper  # To be extended by custom repo modules
    module Sequel
      def insert(domain_object, parent_id = nil)
        mapper_strategy = SchemaUtils::Sequel::DomainObjectSchema.mapper_schema_for(domain_object.class)

        entity_data = SchemaUtils::Sequel.to_row(domain_object, parent_id)
        entity_data.delete(:id)
        entity_data.merge!(_version_id:domain_object._version.id) if mapper_strategy.needs_version?

        Sequel::DB[SchemaUtils::Sequel.to_table_name(domain_object)].insert(entity_data)
      end

      def delete(domain_object)
        condition = EntityMapper.condition_for(domain_object)
        Sequel::DB[SchemaUtils::Sequel.to_table_name(domain_object)].where(condition).update(active: false)
      end

      def update(modified_domain_object, original_object, already_versioned = false)
        raise Dilithium::PersistenceExceptions::ImmutableObjectError, "#{modified_domain_object.class} is immutable - it can't be updated" if (modified_domain_object.is_a? ImmutableDomainObject)

        mapper_strategy = SchemaUtils::Sequel::DomainObjectSchema.mapper_schema_for(modified_domain_object.class)
        modified_data = SchemaUtils::Sequel.to_row(modified_domain_object)
        original_data = SchemaUtils::Sequel.to_row(original_object)

        EntityMapper.verify_identifiers_unchanged(modified_domain_object, modified_data, original_data)

        unless modified_data.eql?(original_data)
          if ! already_versioned && mapper_strategy.needs_version?
            modified_domain_object._version.increment!
            already_versioned = true
          end

          condition = EntityMapper.condition_for(modified_domain_object)
          Sequel::DB[SchemaUtils::Sequel.to_table_name(modified_domain_object)].where(condition).update(modified_data)

          already_versioned
        end
      end
    end
  end
end