module Mapper

  class Sequel
    TRANSACTION_DEFAULT_PARAMS = {:rollback => :reraise}

    def self.transaction(params = TRANSACTION_DEFAULT_PARAMS, &block)
      DB.transaction &block
    end

    def self.insert(entity, parent_id = nil)
      Sequel.check_uow_transaction(entity) unless parent_id  # It's the root

      transaction do
        # First insert entity
        entity_data = entity.to_h
        entity_data[to_parent_reference(entity)] = parent_id if parent_id
        entity.id = DB[to_table_name(entity)].insert(entity_data)

        # Then recurse children for inserting them
        entity.each_child do |child|
          Sequel.insert(child, entity.id)
        end
        entity.id
      end
    end

    def self.delete(entity)
      Sequel.check_uow_transaction(entity)

      transaction do
        # First deactivate entity
        DB[to_table_name(entity)].where(id: entity.id).update(active: false)

        # Then recurse children for deactivating them
        entity.each_child do |child|
          Sequel.delete(child)
        end
      end
    end

    # TODO: make work the methods below with Aggregate Roots

    def self.update(entity)
      Sequel.check_uow_transaction(entity)

      transaction do
        DB[to_table_name(entity)].where(id: entity.id).update(entity.to_h)
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

    # Returns an entity associated parent reference field name.
    #
    # Example:
    #   :employee => :employee_id
    # Params:
    # - entity: BaseEntity instance
    def self.to_parent_reference(entity)
      "#{entity.class.parent}_id".to_sym
    end
  end
end
