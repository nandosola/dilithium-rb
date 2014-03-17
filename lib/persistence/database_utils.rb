# -*- encoding : utf-8 -*-

module Dilithium
  module DatabaseUtils

    # Returns the table name for an entity or reference
    #
    # Example:
    #   Employee => :employees
    #
    # Params:
    # - reference: entity or reference for which you want to get the table name
    # Returns:
    #   Symbol with table name
    def self.to_table_name(reference)
      PersistenceService.table_for(reference.type)
    end

    def self.to_reference_name(attr)
      "#{attr.name.to_s.singularize}_id".to_sym
    end

    def self.to_row(entity, parent_id=nil)
      row = {}
      entity_h = EntitySerializer.to_hash(entity)

      if entity_h[:_version]
        entity_h[:_version_id] = entity_h[:_version][:id]
        entity_h.delete(:_version)
      end

      if parent_id
        parent_ref = "#{entity.class.parent_reference}_id".to_sym
        entity_h[parent_ref] = parent_id if parent_id
      end
      entity_h.each do |attr,value|
        attr_type = entity.class.attribute_descriptors[attr]
        unless [BasicAttributes::ChildReference, BasicAttributes::ParentReference,
                BasicAttributes::MultiReference, BasicAttributes::ImmutableMultiReference].include?(attr_type.class)
          case attr_type
            when BasicAttributes::ImmutableReference
              row[DatabaseUtils.to_reference_name(attr_type)] = value.nil? ? attr_type.default : value.id
            else
              row[attr] = value
          end
        end
      end
      row
    end

    def self.create_tables(*entity_classes)
      SharedVersion.create_table

      entity_classes.each do |entity_class|
        table_name = PersistenceService.table_for(entity_class)

        DB.create_table(table_name) do
          ::DatabaseUtils.to_schema(entity_class){ |type,opts| eval("#{type} #{opts}") }
        end

        SharedVersion.add_to_table(table_name) if PersistenceService.is_inheritance_root?(entity_class)
      end
    end

    def self.create_intermediate_table(dependent, dependee, ref_attr)
      dependent_fk = "#{dependent.to_s.singularize}_id".to_sym
      dependee_fk = "#{ref_attr.to_s.singularize}_id".to_sym
      DB.create_table("#{dependent}_#{dependee}".to_sym) do
        primary_key :id
        foreign_key dependent_fk, dependent
        foreign_key dependee_fk, ref_attr.pluralize.to_sym
      end
    end

    def self.to_schema(entity_class)
      attrs = case PersistenceService.mapper_for(entity_class)
               when :leaf
                 yield 'primary_key', ":#{entity_class.identifier_names}"
                 entity_class.attributes

               when :class
                 if PersistenceService.is_inheritance_root?(entity_class)
                   yield 'primary_key', ":#{entity_class.identifier_names}"
                   yield 'String', ':_type'
                 else
                   super_table = PersistenceService.table_for(entity_class.superclass)
                   yield 'foreign_key',
                     ":#{entity_class.identifier_names}, :#{super_table}, :key => :#{entity_class.identifier_names}, :primary_key => true"
                 end
                 entity_class.self_attributes
             end

      attrs.each do |attr|
        unless entity_class.identifier_names == attr.name
          case attr
            # TODO Refactor this behaviour to a class
            when BasicAttributes::ParentReference, BasicAttributes::ImmutableReference
              name = if attr.type.nil?
                       attr.name.to_s.pluralize
                     else
                       PersistenceService.table_for(attr.type)
                     end
              yield 'foreign_key', ":#{DatabaseUtils.to_reference_name(attr)}, :#{name}"
            when BasicAttributes::ExtendedGenericAttribute
              default = attr.default.nil? ? 'nil' : attr.default
              default = "'#{default}'" if default.is_a?(String) && attr.default
              yield "#{attr.type.superclass}", ":#{attr.name}, :default => #{attr.to_generic_type(default)}"
            when BasicAttributes::GenericAttribute
              default = attr.default.nil? ? 'nil' : attr.default
              default = "'#{default}'" if default.is_a?(String) && attr.default
              yield "#{attr.type}", ":#{attr.name}, :default => #{default}"
            when BasicAttributes::MultiReference, BasicAttributes::ImmutableMultiReference
              dependent = PersistenceService.table_for(entity_class)
              create_intermediate_table(dependent, attr.name, attr.reference_path.last.underscore)
          end
        end
      end
    end
  end
end
