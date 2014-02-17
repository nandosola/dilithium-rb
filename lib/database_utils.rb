# -*- encoding : utf-8 -*-
require 'version'
require 'basic_attributes'

module DatabaseUtils

  # Returns an entity associated DB table name
  #
  # Example:
  #   Employee => :employees
  #
  # Params:
  # - entity: entity for converting class to table name
  # Returns:
  #   Symbol with table name
  def self.to_table_name(entity)
    #TODO : extract this to an utilities class/module
    case entity
      # TODO refactor to a single class method in IdPk
      when BaseEntity, Association::LazyEntityReference, Association::ImmutableEntityReference  #TODO make this inherit from IdPK
        table_name_for(entity.type)
      when Class
        table_name_for(entity)
    end
  end

  def self.table_name_for(klazz)
    path = klazz.to_s.split('::')
    last = if path.last == 'Immutable'
             path[-2]
           else
             path.last
           end

    last.underscore.downcase.pluralize.to_sym
  end

  def self.to_reference_name(attr)
    "#{attr.name.to_s.singularize}_id".to_sym
  end

  def self.create_tables(*entity_classes)
    create_versions_table unless DB.table_exists?(:_versions)
    entity_classes.each do |entity_class|
      table_name = entity_class.to_s.split('::').last.underscore.downcase.pluralize

      DB.create_table(table_name) do
        ::DatabaseUtils.schemify(entity_class){ |type,opts| eval("#{type} #{opts}") }
      end
    end
  end

  def self.create_versions_table
    DB.create_table(:_versions) do
      ::DatabaseUtils.schemify(Version){ |type,opts| eval("#{type} #{opts}") }
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

  def self.schemify(entity_class)
    entity_class.attributes.each do |attr|
      if entity_class.pk == attr.name
        yield 'primary_key', ":#{attr.name}"
      else
        case attr
          # TODO Refactor this behaviour to a class
          when BasicAttributes::ParentReference, BasicAttributes::ImmutableReference, BasicAttributes::Version
            name = if attr.type.nil? || Version == attr.type
                     attr.name.to_s.pluralize
                   else
                     attr.type.to_s.split('::').last.underscore.pluralize
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
