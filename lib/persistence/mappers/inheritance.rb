# -*- encoding : utf-8 -*-

module Dilithium
  module InheritanceMapper

    def self.for(entity_class)
      case PersistenceService.mapper_for(entity_class)
        when :leaf
          Sequel::LeafTableInheritance
        when :class
          Sequel::ClassTableInheritance
      end
    end

    module Sequel

      class ClassTableInheritance
        def self.insert(entity, parent_id = nil)
          entity_data = SchemaUtils::Sequel.to_row(entity, parent_id)
          entity_data.delete(:id)

          superclass_list = PersistenceService.superclass_list(entity.class)
          root_class = superclass_list.last

          rows = split_row(superclass_list, entity_data)
          rows[root_class][:_type] = PersistenceService.table_for(entity.class).to_s
          rows[root_class][:_version_id] = entity._version.id

          id = Sequel::DB[PersistenceService.table_for(root_class)].insert(rows[root_class])

          superclass_list[0..-2].reverse.each do |klazz|
            rows[klazz][:id] = id
            Sequel::DB[PersistenceService.table_for(klazz)].insert(rows[klazz])
          end

          id
        end

        def self.delete(entity)
          inheritance_root = PersistenceService.inheritance_root_for(entity.class)
          Sequel::DB[PersistenceService.table_for(inheritance_root)].where(id: entity.id).update(active: false)
        end

        def self.update(modified_entity, original_entity, already_versioned = false)
          raise Dilithium::PersistenceExceptions::ImmutableObjectError, "#{modified_entity.class} is immutable - it can't be updated" if (modified_entity.is_a? ImmutableDomainObject)

          modified_data = SchemaUtils::Sequel.to_row(modified_entity)
          original_data = SchemaUtils::Sequel.to_row(original_entity)

          unless modified_data.eql?(original_data)
            unless already_versioned
              modified_entity._version.increment!
              already_versioned = true
            end

            EntityMapper.verify_identifiers_unchanged(modified_entity, modified_data, original_data)

            superclass_list = PersistenceService.superclass_list(modified_entity.class)
            rows = split_row(superclass_list, modified_data)
            rows[superclass_list.last][:_type] = PersistenceService.table_for(modified_entity.class).to_s

            rows.each do |klazz, row|
              Sequel::DB[PersistenceService.table_for(klazz)].where(id: modified_entity.id).update(row)
            end

            already_versioned
          end
        end

        def self.table_name_for_intermediate(entity, attr_name)
          defining_entity = PersistenceService.superclass_list(entity).find do |klazz|
            klazz.attribute_names.include?(attr_name) || PersistenceService.is_inheritance_root?(klazz)
          end

          PersistenceService.table_for(defining_entity)
        end

        private

        def self.split_row(superclass_list, row_h)
          superclass_list.inject({}) do |memo, klazz|
            memo[klazz] = {}

            klazz.self_attributes.each do |attr|
              name = case attr
                       when BasicAttributes::ImmutableReference,
                           BasicAttributes::ChildReference,
                           BasicAttributes::ParentReference

                         SchemaUtils::Sequel.to_reference_name(attr)
                       else
                         attr.name
                     end

              memo[klazz][name] = row_h[name] if row_h.has_key?(name)
            end

            memo
          end
        end
        private_class_method(:split_row)
      end

      class LeafTableInheritance
        def self.insert(domain_object, parent_id = nil)
          mapper_strategy = SchemaUtils::Sequel::DomainObjectSchema.mapper_schema_for(domain_object.class)

          entity_data = SchemaUtils::Sequel.to_row(domain_object, parent_id)
          entity_data.delete(:id)
          entity_data.merge!(_version_id:domain_object._version.id) if mapper_strategy.needs_version?

          Sequel::DB[SchemaUtils::Sequel.to_table_name(domain_object)].insert(entity_data)
        end

        def self.delete(domain_object)
          condition = EntityMapper.condition_for(domain_object)
          Sequel::DB[SchemaUtils::Sequel.to_table_name(domain_object)].where(condition).update(active: false)
        end

        def self.update(modified_domain_object, original_object, already_versioned = false)
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

        def self.table_name_for_intermediate(entity, attr_name)
          PersistenceService.table_for(entity)
        end
      end

    end
  end
end