require_relative 'basic_attributes'
require_relative 'entity_serializer'

module Mapper

  class Sequel
    # TODO - evaluate deferrable transactions
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
     check_uow_transaction(entity) unless parent_id  # It's the root

      # First insert entity
      entity_data = EntitySerializer.to_row(entity, parent_id)
      entity_data.delete(:id)
      entity.id = DB[to_table_name(entity)].insert(entity_data)

      # Then recurse children for inserting them
      entity.each_child do |child|
        insert(child, entity.id)
      end

      # Then recurse many for inserting the intermediate table
      entity.each_multi_reference do |many|
        insert_in_intermediate_table(entity, many)
      end
    end

    def self.delete(entity)
     check_uow_transaction(entity)

      DB[to_table_name(entity)].where(id: entity.id).update(active: false)

      entity.each_child do |child|
        delete(child)
      end
    end

    def self.update(modified_entity, original_entity)
     check_uow_transaction(modified_entity)

      modified_data = EntitySerializer.to_row(modified_entity)
      original_data = EntitySerializer.to_row(original_entity)

      unless modified_data.eql?(original_data)
        DB[to_table_name(modified_entity)].where(id: modified_entity.id).update(modified_data)
      end

      modified_entity.each_child do |child|
        if child.id.nil?
          insert(child, modified_entity.id)
        else
          update(child, original_entity.find_child do |c|
            child.id == c.id
          end)
        end
      end

      original_entity.each_child do |child|
        delete(child) if modified_entity.find_child{|c| child.id == c.id}.nil?
      end

      modified_entity.each_multi_reference do |ref|
        insert_in_intermediate_table(modified_entity, ref, :update)
      end

     original_entity.each_multi_reference do |ref|
       delete_in_intermediate_table(original_entity, ref) if modified_entity.find_multi_reference{|r| ref.id == r.id}.nil?
     end

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
      #TODO : extract this to an utilities class/module
      klazz = case entity
                when BaseEntity
                  entity.class
                when Class
                  entity
              end
      klazz.to_s.split('::').last.underscore.downcase.pluralize.to_sym
    end


    private
    def self.insert_in_intermediate_table(dependee, dependent, from=:insert)
      table_dependee = to_table_name(dependee)
      table_dependent = to_table_name(dependent)
      intermediate_table_name = :"#{table_dependee}_#{table_dependent}"
      column_dependee = :"#{table_dependee.to_s.singularize}_id"
      column_dependent = :"#{table_dependent.to_s.singularize}_id"

      data = { column_dependee => dependee.id,
              column_dependent => dependent.id }

      # TODO refactor so that this op below is not always performed (only in :update)
      if DB[intermediate_table_name].where(column_dependent => dependent.id).
          where(column_dependee => dependee.id).all.empty?

        transaction(:rollback=>:nop) do
          DB[intermediate_table_name].insert(data)
        end
      end
    end

    # TODO refactor this
    def self.delete_in_intermediate_table(dependee, dependent)
      table_dependee = to_table_name(dependee)
      table_dependent = to_table_name(dependent)
      intermediate_table_name = :"#{table_dependee}_#{table_dependent}"
      column_dependee = :"#{table_dependee.to_s.singularize}_id"
      column_dependent = :"#{table_dependent.to_s.singularize}_id"

      transaction(:rollback=>:nop) do
        DB[intermediate_table_name].where(column_dependent => dependent.id).
            where(column_dependee => dependee.id).delete
      end
    end

    def self.check_uow_transaction(base_entity)
      raise RuntimeError, "Invalid Transaction" if !base_entity.class.has_parent? && base_entity.transactions.empty?
    end

    def self.schemify(entity_class)
      entity_class.attributes.each do |attr|
        if entity_class.pk == attr.name
          yield 'primary_key', ":#{attr.name}"
        else
          case attr
            when BasicAttributes::ParentReference, BasicAttributes::ValueReference
              yield 'foreign_key', ":#{attr.reference}, :#{attr.name.to_s.pluralize}"
            when BasicAttributes::Attribute
              default = attr.default.nil? ? 'nil' : attr.default
              yield "#{attr.type}", ":#{attr.name}, :default => #{default}"
            when BasicAttributes::ManyReference
              dependent = to_table_name(entity_class)
              create_intermediate_table(dependent, attr.name)
          end
        end
      end
    end

    def self.create_intermediate_table(dependent, dependee)
      dependent_fk = "#{dependent.to_s.singularize}_id".to_sym
      dependee_fk = "#{dependee.to_s.singularize}_id".to_sym
      DB.create_table("#{dependent}_#{dependee}".to_sym) do
        primary_key :id
        foreign_key dependent_fk, dependent
        foreign_key dependee_fk, dependee
      end
    end

  end
end
