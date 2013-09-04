require 'basic_attributes'

module Mapper

  class Sequel
    TRANSACTION_DEFAULT_PARAMS = {:rollback => :reraise}

    def self.transaction(params = TRANSACTION_DEFAULT_PARAMS, &block)
      DB.transaction &block
    end

    def self.create_tables(*entity_classes)
      entity_classes.each do |entity_class|
        table_name = entity_class.to_s.split('::').last.underscore.downcase.pluralize

        DB.create_table(table_name) do
          Mapper::Sequel.schemify(entity_class){ |type,opts| eval("#{type} #{opts}") }
        end
      end
    end
    
    def self.insert(entity, parent_id = nil)
      Sequel.check_uow_transaction(entity) unless entity.class.has_parent?  # It's the root
      
      transaction do
        references = Hash.new

        # First insert entity
        entity_data = Sequel.entity_to_row(entity, parent_id)
        id = DB[to_table_name(entity)].insert(entity_data)
        references[entity] = {:id => id, :parent_id => parent_id}

        # Then recurse children for inserting them
        entity.each_child do |child|
          child_references = Sequel.insert(child, id)
          references.merge!(child_references)
        end

        references
      end
    end

    def self.delete(entity)
      Sequel.check_uow_transaction(entity) unless entity.class.has_parent?  # It's the root

      transaction do
        # First deactivate entity
        DB[to_table_name(entity)].where(id: entity.id).update(active: false)

        # Then recurse children for deactivating them
        entity.each_child do |child|
          Sequel.delete(child)
        end

        entity
      end
    end

    def self.update(modified_entity, original_entity=nil)
      Sequel.check_uow_transaction(modified_entity) unless modified_entity.class.has_parent?  # It's the root
      entity_data = Sequel.entity_to_row(modified_entity)

      transaction do
        DB[to_table_name(modified_entity)].where(id: modified_entity.id).update(entity_data)
      end
    end

    def self.reload(base_entity)
      Sequel.check_uow_transaction(base_entity)
      name = base_entity.class.to_s.split('::').last.underscore.downcase
      table = name.pluralize
    end

    private
    def self.check_uow_transaction(base_entity)
      raise RuntimeError, "Invalid Transaction" if base_entity.transactions.empty?
    end

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
      entity.class.to_s.split('::').last.underscore.downcase.pluralize.to_sym
    end

    def self.schemify(entity_class)
      entity_class.attributes.each do |attr|
        if entity_class.pk == attr.name
          yield 'primary_key', ":#{attr.name}"
        else
          if [BasicAttributes::ParentReference, BasicAttributes::ValueReference].include?(attr.class)
            yield 'foreign_key', ":#{attr.reference}, :#{attr.name.to_s.pluralize}"
          elsif attr.is_a?(BasicAttributes::Attribute)
            default = attr.default.nil? ? 'nil' : attr.default
            yield "#{attr.type}", ":#{attr.name}, :default => #{default}"
          end
        end
      end
    end

    # Returns an entity associated parent reference field name.
    #
    # Example:
    #   :employee => :employee_id
    # Params:
    # - entity: BaseEntity instance
    def self.to_parent_reference(entity)
      "#{entity.class.parent_reference}_id".to_sym
    end

    # TODO: extract this to a Serializer class?
    def self.to_hash(entity)
      h = {}
      entity.instance_variables.each do |attr|
        attr_name = attr.to_s[1..-1].to_sym
        attr_value = entity.instance_variable_get(attr)
        h[attr_name] =  attr_value
      end
      h
    end

    def self.entity_to_row(entity, parent_id=nil)
      row = {}
      entity_h = Sequel.to_hash(entity)
      entity_h[to_parent_reference(entity)] = parent_id if parent_id
      entity_h.each do |attr,value|
        attr_type = entity.class.class_variable_get(:'@@attributes')[attr]
        unless [BasicAttributes::ChildReference, BasicAttributes::ParentReference].include?(attr_type.class)
          if attr_type.is_a?(BasicAttributes::ValueReference)
            row[attr_type.reference] = value.nil? ? attr_type.default : value.id
          else
            row[attr] = value
          end
        end
      end
      row
    end

  end
end
