# -*- encoding : utf-8 -*-

module Dilithium
  #TODO Change to Sequel::SchemaUtils::Sequel and change class names
  module SchemaUtils
    module Sequel
      module DomainObjectSchema

        class BaseSchema
          def initialize(domain_class)
            @domain_class = domain_class
          end
        end

        class BaseEntitySchema < BaseSchema
          def define_primary_keys(&block)
            block.call('primary_key', ":#{@domain_class.identifier_names.first}")
          end

          def define_inheritance_keys(&block)
            super_table = PersistenceService.table_for(@domain_class.superclass)
            key = @domain_class.identifier_names.first
            block.call('foreign_key', ":#{key}, :#{super_table}, :key => :#{key}, :primary_key => true")
          end

          def needs_version?
            PersistenceService.is_inheritance_root?(@domain_class)
          end

          def soft_delete?
            true
          end
        end

        class BaseValueSchema < BaseSchema
          def define_primary_keys(&block)
            @domain_class.identifier_names.each do |id|
              attr = @domain_class.attribute_descriptors[id]
              default = attr.default.nil? ? 'nil' : attr.default
              default = "'#{default}'" if default.is_a?(String) && attr.default
              if @domain_class.identifier_names.length == 1
                block.call("#{attr.generic_type}", ":#{attr.name}, :default => #{attr.to_generic_type(default)}, :primary_key => true")
              else
                block.call("#{attr.generic_type}", ":#{attr.name}, :default => #{attr.to_generic_type(default)}")
              end
            end

            if @domain_class.identifier_names.length > 1
              keys = @domain_class.identifier_names.join(",:")
              block.call('primary_key', "[:#{keys}]")
            end
          end

          def define_inheritance_keys(&block)
            super_table = PersistenceService.table_for(@domain_class.superclass)
            keys = @domain_class.identifier_names.join(",:")
            block.call('foreign_key',
                       ":#{keys}, :#{super_table}, :key => :#{keys}, :primary_key => true")
          end

          def needs_version?
            false
          end

          def soft_delete?
            false
          end
        end

        class Mapper
          def initialize(domain_class)
            @domain_class = domain_class
          end

          def define_schema(&block)
            define_base_schema(&block)

            self.schema_attributes.each do |attr|
              case attr
                # TODO Refactor this behaviour to a class
                when BasicAttributes::ParentReference, BasicAttributes::ImmutableReference
                  name = if attr.type.nil?
                           attr.name.to_s.pluralize
                         else
                           PersistenceService.table_for(attr.type)
                         end
                  block.call('foreign_key', ":#{SchemaUtils::Sequel.to_reference_name(attr)}, :#{name}")
                when BasicAttributes::GenericAttribute
                  default = attr.default.nil? ? 'nil' : attr.default
                  default = "'#{default}'" if default.is_a?(String) && attr.default
                  block.call("#{attr.generic_type}", ":#{attr.name}, :default => #{attr.to_generic_type(default)}")
                when BasicAttributes::MultiReference, BasicAttributes::ImmutableMultiReference
                  dependent = PersistenceService.table_for(@domain_class)
                  create_intermediate_table(dependent, attr.name, attr.reference_path.last.underscore)
              end
            end
          end

          def needs_version?
            key_schema.needs_version?
          end

          def key_schema
            if @domain_class <= BaseEntity
              BaseEntitySchema.new(@domain_class)
            elsif @domain_class <= BaseValue
              BaseValueSchema.new(@domain_class)
            else
              raise ArgumentError, "#{@domain_class} is neither a BaseEntity nor a BaseValue"
            end
          end

          def create_intermediate_table(dependent, dependee, ref_attr)
            dependent_fk = "#{dependent.to_s.singularize}_id".to_sym
            dependee_fk = "#{ref_attr.to_s.singularize}_id".to_sym
            DB.create_table("#{dependent}_#{dependee}".to_sym) do
              primary_key :id
              foreign_key dependent_fk, dependent
              foreign_key dependee_fk, ref_attr.pluralize.to_sym
            end
          end

          def remove_identifier_attributes(attrs)
            attrs.reject{ |a| @domain_class.identifier_names.include?(a.name) }
          end
        end

        class LeafInheritanceMapper < Mapper
          def schema_attributes
            remove_identifier_attributes(@domain_class.attributes)
          end

          def define_base_schema(&block)
            key_schema.define_primary_keys(&block)
          end
        end

        class ClassInheritanceMapper < Mapper
          def schema_attributes
            remove_identifier_attributes(@domain_class.self_attributes)
          end

          def define_base_schema(&block)
            if PersistenceService.is_inheritance_root?(@domain_class)
              key_schema.define_primary_keys(&block)
              block.call('String', ':_type')
            else
              key_schema.define_inheritance_keys(&block)
            end
          end
        end

        ATTRIBUTE_MAPPERS = {
          leaf: LeafInheritanceMapper,
          class: ClassInheritanceMapper
        }

        def self.mapper_schema_for(domain_class)
          ATTRIBUTE_MAPPERS[PersistenceService.mapper_for(domain_class)].new(domain_class)
        end
      end


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
        PersistenceService.table_for(reference._type)
      end

      def self.to_reference_name(attr)
        "#{attr.name.to_s.singularize}_id".to_sym
      end

      def self.to_row(domain_object, parent_id=nil)
        mapper_strategy = DomainObjectSchema.mapper_schema_for(domain_object.class)

        row = {}

        entity_h = if mapper_strategy.needs_version?
                     EntitySerializer.to_hash(domain_object)
                   else
                     EntitySerializer.to_hash(domain_object, :without => SharedVersion)
                   end

        if entity_h[:_version]
          entity_h[:_version_id] = entity_h[:_version][:id]
          entity_h.delete(:_version)
        end

        if parent_id
          parent_ref = "#{domain_object.class.parent_reference}_id".to_sym
          entity_h[parent_ref] = parent_id if parent_id
        end

        entity_h.each do |attr,value|
          attr_type = domain_object.class.attribute_descriptors[attr]
          unless [BasicAttributes::ChildReference, BasicAttributes::ParentReference,
                  BasicAttributes::MultiReference, BasicAttributes::ImmutableMultiReference].include?(attr_type.class)
            case attr_type
              when BasicAttributes::ImmutableReference
                row[SchemaUtils::Sequel.to_reference_name(attr_type)] = value.nil? ? attr_type.default : value.id
              else
                row[attr] = value
            end
          end
        end
        row
      end

      def self.create_tables(*domain_classes)
        SharedVersion.create_table

        domain_classes.each do |domain_class|
          table_name = PersistenceService.table_for(domain_class)
          mapper_strategy = DomainObjectSchema.mapper_schema_for(domain_class)

          DB.create_table(table_name) do
            mapper_strategy.define_schema{ |type,opts| eval("#{type} #{opts}") }
          end

          SharedVersion.add_to_table(table_name) if mapper_strategy.needs_version?
        end
      end

      def self.get_schema(table_sym)
        $database.schema(table_sym).each_with_object(Hash.new) do |s, h|
          h[s[0]] = {
            type: s[1][:db_type],
            primary_key: s[1][:primary_key]
          }
        end
      end
    end
  end
end
