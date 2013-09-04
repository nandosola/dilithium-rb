require_relative 'basic_attributes'
require_relative 'entity_serializer'

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
      Sequel.check_uow_transaction(entity) unless parent_id  # It's the root
      
      transaction do
        # First insert entity
        entity_data = EntitySerializer.to_row(entity, parent_id)
        entity_data.delete(:id)
        entity.id = DB[to_table_name(entity)].insert(entity_data)

        # Then recurse children for inserting them
        entity.each_child do |child|
          Sequel.insert(child, entity.id)
        end
        entity.id
      end # transaction
    end

    def self.delete(entity)
      Sequel.check_uow_transaction(entity)

      transaction do
        DB[to_table_name(entity)].where(id: entity.id).update(active: false)

        entity.each_child do |child|
          Sequel.delete(child)
        end
      end
    end

    def self.update(modified_entity, original_entity)
      Sequel.check_uow_transaction(modified_entity)

      modified_data = EntitySerializer.to_row(modified_entity)
      original_data = EntitySerializer.to_row(original_entity)

      # TODO minimize transactions
      transaction do
        unless modified_data.eql?(original_data)
          DB[to_table_name(modified_entity)].where(id: modified_entity.id).update(modified_data)
        end

        modified_entity.each_child do |child|
          if child.id.nil?
            Sequel.insert(child, modified_entity.id)
          else
            Sequel.update(child, original_entity.find_child do |c|
              child.id == c.id
            end)
          end
        end

        original_entity.each_child do |child|
          Sequel.delete(child) if modified_entity.find_child{|c| child.id == c.id}.nil?
        end
      end # transaction

    end

    def self.reload(base_entity)
      Sequel.check_uow_transaction(base_entity)
      name = base_entity.class.to_s.split('::').last.underscore.downcase
      table = name.pluralize
    end

    private
    def self.check_uow_transaction(base_entity)
      raise RuntimeError, "Invalid Transaction" if !base_entity.class.has_parent? && base_entity.transactions.empty?
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

  end
end