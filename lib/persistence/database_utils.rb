# -*- encoding : utf-8 -*-

module Dilithium
  module DatabaseUtils

    # Returns an model associated DB table name
    #
    # Example:
    #   Employee => :employees
    #
    # Params:
    # - model: model for converting class to table name
    # Returns:
    #   Symbol with table name
    def self.to_table_name(entity)
      #TODO : extract this to an utilities class/module
      case entity
        # TODO refactor to a single class method in IdPk
        when BaseEntity, Association::LazyEntityReference, Association::ImmutableEntityReference  #TODO make this inherit from IdPK
          PersistenceService.table_for(entity.type)
        when Class
          PersistenceService.table_for(entity)
      end
    end

    def self.to_reference_name(attr)
      "#{attr.name.to_s.singularize}_id".to_sym
    end

    def self.to_row(entity, parent_id=nil)
      row = {}
      entity_h = EntitySerializer.to_hash(entity)
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
      attr = case PersistenceService.mapper_for(entity_class)
               when :leaf
                 entity_class.attributes
               when :class
                 yield 'primary_key', ":#{entity_class.pk}"

                 if PersistenceService.is_inheritance_root?(entity_class)
                   yield 'String', ':_type'
                 else
                   super_table = PersistenceService.table_for(entity_class.superclass)
                   yield 'foreign_key', ":#{entity_class.pk}, :#{super_table}"
                 end
                 entity_class.self_attributes
             end

      attr.each do |attr|
        if entity_class.pk == attr.name
          yield 'primary_key', ":#{attr.name}"
        else
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
              dependent = DatabaseUtils.to_table_name(entity_class)
              create_intermediate_table(dependent, attr.name, attr.reference_path.last.downcase)
          end
        end
      end
    end
  end
end
