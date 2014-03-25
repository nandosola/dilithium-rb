# -*- encoding : utf-8 -*-

module Dilithium
  module EntityMapper

    def self.condition_for(domain_object)
      domain_object.class.identifiers.each_with_object(Hash.new) do | id_desc, h |
        id = id_desc[:identifier]
        h[id] = domain_object.instance_variable_get(:"@#{id}".to_sym)
      end
    end

    def self.verify_identifiers_unchanged(modified_domain_object, modified_data, original_data)
      modified_domain_object.class.identifiers.each do |id_desc|
        id = id_desc[:identifier]
        raise Dilithium::PersistenceExceptions::IllegalUpdateError, "Illegal update, identifiers don't match" unless original_data[id] == modified_data[id]
      end
    end

    module Sequel
      TRANSACTION_DEFAULT_PARAMS = {rollback: :reraise, deferrable: true}

      def self.transaction(params = TRANSACTION_DEFAULT_PARAMS, &block)
        DB.transaction &block
      end

      def self.check_uow_transaction(base_entity)
        #TODO In the case where base_entity is not a root, should we also check that its root HAS a transaction?
        raise RuntimeError, 'Invalid Transaction' if !base_entity.class.has_parent? && base_entity.transactions.empty?
      end

      def self.insert(entity, parent_id = nil)
        check_uow_transaction(entity) unless parent_id  # It's the root

        # First insert version when persisting the root; no need to lock the row/table
        entity._version.insert! if entity.is_a?(BaseEntity) && parent_id.nil?

        # Then insert model
        # There's always inheritance (default type)
        id = InheritanceMapper.for(entity.class).insert(entity, parent_id)
        entity.id = id if entity.respond_to? :id=

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

        if entity.is_a?(BaseEntity) && ! already_versioned
          entity._version.increment!
          already_versioned = true
        end

        InheritanceMapper.for(entity.class).delete(entity)

        entity.each_child do |child|
          delete(child, already_versioned)
        end
      end

      def self.update(modified_entity, original_entity, already_versioned=false)
        check_uow_transaction(modified_entity)

        already_versioned = InheritanceMapper.for(modified_entity.class).update(modified_entity, original_entity, already_versioned)

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
        column_dependee, column_dependent, intermediate_table_name = intermediate_table_descriptor(dependee, dependent, ref_attr)

        data = { column_dependee => dependee.id,
                 column_dependent => dependent.id }

        # TODO refactor so that this op below is not always performed (only in :update)
        if Sequel::DB[intermediate_table_name].
          where(column_dependent => dependent.id).
          where(column_dependee => dependee.id).all.empty?

          Sequel.transaction(:rollback=>:nop) do
            Sequel::DB[intermediate_table_name].insert(data)
          end
        end
      end
      private_class_method(:insert_in_intermediate_table)

      def self.delete_in_intermediate_table(dependee, dependent, ref_attr)
        column_dependee, column_dependent, intermediate_table_name = intermediate_table_descriptor(dependee, dependent, ref_attr)

        Sequel.transaction(:rollback=>:nop) do
          Sequel::DB[intermediate_table_name].where(column_dependent => dependent.id).
            where(column_dependee => dependee.id).delete
        end
      end
      private_class_method(:delete_in_intermediate_table)

      def self.intermediate_table_descriptor(dependee, dependent, ref_attr)
        table_dependee = InheritanceMapper.for(dependee.class).table_name_for_intermediate(dependee.class, ref_attr)
        intermediate_table_name = :"#{table_dependee}_#{ref_attr}"
        column_dependee = :"#{table_dependee.to_s.singularize}_id"

        table_dependent = InheritanceMapper.for(dependent._type).table_name_for_intermediate(dependent._type, ref_attr)
        column_dependent = :"#{table_dependent.to_s.singularize}_id"

        return column_dependee, column_dependent, intermediate_table_name
      end
      private_class_method(:intermediate_table_descriptor)


    end
  end
end