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
        check_uow_transaction(entity) unless parent_id  # It's the root

        # First insert version when persisting the root; no need to lock the row/table
        if parent_id.nil?
          entity._version.insert!
        end

        # Then insert model
        entity_data = DatabaseUtils.to_row(entity, parent_id)
        entity_data.delete(:id)
        entity.id = DB[DatabaseUtils.to_table_name(entity)].insert(entity_data.merge(_version_id:entity._version.id))

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
        check_uow_transaction(entity)

        unless already_versioned
          entity._version.increment!
          already_versioned = true
        end

        DB[DatabaseUtils.to_table_name(entity)].where(id: entity.id).update(active: false)

        entity.each_child do |child|
          delete(child, already_versioned)
        end
      end

      def self.update(modified_entity, original_entity, already_versioned=false)
        check_uow_transaction(modified_entity)

        modified_data = DatabaseUtils.to_row(modified_entity)
        original_data = DatabaseUtils.to_row(original_entity)

        unless modified_data.eql?(original_data)
          unless already_versioned
            modified_entity._version.increment!
            already_versioned = true
          end
          DB[DatabaseUtils.to_table_name(modified_entity)].where(id: modified_entity.id).update(modified_data)
        end

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

      def self.insert_in_intermediate_table(dependee, dependent, ref_attr, from=:insert)
        table_dependee = DatabaseUtils.to_table_name(dependee)
        table_dependent = DatabaseUtils.to_table_name(dependent)
        intermediate_table_name = :"#{table_dependee}_#{ref_attr}"
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

      def self.delete_in_intermediate_table(dependee, dependent, ref_attr)
        table_dependee = DatabaseUtils.to_table_name(dependee)
        table_dependent = DatabaseUtils.to_table_name(dependent)
        intermediate_table_name = :"#{table_dependee}_#{ref_attr}"
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

    end
  end
end