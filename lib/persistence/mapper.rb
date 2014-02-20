# -*- encoding : utf-8 -*-

module Dilithium
  module Mapper

    class NullMapper
    end

    class Sequel
      TRANSACTION_DEFAULT_PARAMS = {rollback: :reraise, deferrable: true}

      def self.transaction(params = TRANSACTION_DEFAULT_PARAMS, &block)
        DB.transaction &block
      end

      def self.insert(entity, parent_id = nil)
        Sequel.check_uow_transaction(entity) unless parent_id  # It's the root

        # First insert version when persisting the root; no need to lock the row/table
        if parent_id.nil?
          entity._version.insert!
        end

        # Then insert model
        mapper_for(entity).insert(entity, parent_id)

        # Then recurse children for inserting them
        entity.each_child do |child|
          insert(child, entity.id)
        end

        # Then recurse multi_ref for inserting the intermediate table
        entity.each_multi_reference(true) do |ref, ref_attr|
          insert_in_intermediate_table(entity, ref, ref_attr)
        end
      end

      def self.delete(entity, already_versioned=false)
        Sequel.check_uow_transaction(entity)

        unless already_versioned
          entity._version.increment!
          already_versioned = true
        end

        mapper_for(entity).delete(entity)

        entity.each_child do |child|
          delete(child, already_versioned)
        end
      end

      def self.update(modified_entity, original_entity, already_versioned=false)
        Sequel.check_uow_transaction(modified_entity)

        already_versioned = mapper_for(modified_entity).update(modified_entity, original_entity, already_versioned)

        modified_entity.each_child do |child|
          if child.id.nil?
            unless already_versioned
              modified_entity._version.increment!
              already_versioned = true
            end
            insert(child, modified_entity.id)
          else
            update(child, (original_entity.find_child do |c|
              child.class == c.class && child.id == c.id
            end), already_versioned)
          end
        end

        original_entity.each_child do |child|
          if modified_entity.find_child{|c| child.class == c.class && child.id == c.id}.nil?
            unless already_versioned
              modified_entity._version.increment!
              already_versioned = true
            end
            delete(child, already_versioned)
          end
        end

        modified_entity.each_multi_reference do |ref, ref_attr|
          insert_in_intermediate_table(modified_entity, ref, ref_attr, :update)
        end

        original_entity.each_multi_reference do |ref, ref_attr|
          found_ref = modified_entity.find_multi_reference{|r, attr| ref_attr == attr && ref.id == r.id}
          delete_in_intermediate_table(original_entity, ref, ref_attr) if found_ref.nil?
        end
      end

      private

      def self.check_uow_transaction(base_entity)
        #TODO In the case where base_entity is not a root, should we also check that its root HAS a transaction?
        raise RuntimeError, "Invalid Transaction" if !base_entity.class.has_parent? && base_entity.transactions.empty?
      end

      def self.mapper_for(entity)
        case PersistenceService.mapper_for(entity.class)
          when :leaf
            LeafTableInheritance
          when :class
            ClassTableInheritance
        end
      end

      private

      def self.insert_in_intermediate_table(dependee, dependent, ref_attr, from=:insert)
        column_dependee, column_dependent, intermediate_table_name = intermediate_table_descriptor(dependee, dependent, ref_attr)

        data = { column_dependee => dependee.id,
                 column_dependent => dependent.id }

        # TODO refactor so that this op below is not always performed (only in :update)
        if Sequel::DB[intermediate_table_name].where(column_dependent => dependent.id).
          where(column_dependee => dependee.id).all.empty?

          Sequel.transaction(:rollback=>:nop) do
            Sequel::DB[intermediate_table_name].insert(data)
          end
        end
      end

      def self.delete_in_intermediate_table(dependee, dependent, ref_attr)
        column_dependee, column_dependent, intermediate_table_name = intermediate_table_descriptor(dependee, dependent, ref_attr)

        Sequel.transaction(:rollback=>:nop) do
          Sequel::DB[intermediate_table_name].where(column_dependent => dependent.id).
            where(column_dependee => dependee.id).delete
        end
      end

      def self.intermediate_table_descriptor(dependee, dependent, ref_attr)
        table_dependee = mapper_for(dependee).table(dependee)
        table_dependent = mapper_for(dependent).table(dependent)

        intermediate_table_name = :"#{table_dependee}_#{ref_attr}"

        column_dependee = :"#{table_dependee.to_s.singularize}_id"
        column_dependent = :"#{table_dependent.to_s.singularize}_id"
        return column_dependee, column_dependent, intermediate_table_name
      end

      class ClassTableInheritance

      end

      class LeafTableInheritance
        def self.insert(entity, parent_id = nil)
          entity_data = DatabaseUtils.to_row(entity, parent_id)
          entity_data.delete(:id)
          entity.id = Sequel::DB[DatabaseUtils.to_table_name(entity)].insert(entity_data.merge(_version_id:entity._version.id))
        end

        def self.delete(entity)
          Sequel::DB[DatabaseUtils.to_table_name(entity)].where(id: entity.id).update(active: false)
        end

        def self.update(modified_entity, original_entity, already_versioned = false)
          modified_data = DatabaseUtils.to_row(modified_entity)
          original_data = DatabaseUtils.to_row(original_entity)

          unless modified_data.eql?(original_data)
            unless already_versioned
              modified_entity._version.increment!
              already_versioned = true
            end

            Sequel::DB[DatabaseUtils.to_table_name(modified_entity)].where(id: modified_entity.id).update(modified_data)

            already_versioned
          end
        end

        def self.table(entity)
          PersistenceService.table_for(entity.class)
        end
      end
    end
  end
end