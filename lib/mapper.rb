module Mapper
  module Sequel
    DB = $database

    def self.included(base)
      base.class_eval do
        def create(parent_identity={})
          check_uow_transaction if parent_identity.empty?  # It's the root
          parent_name = self.class.to_s.split('::').last.underscore.downcase
          parent_table = parent_name.pluralize

          DB.transaction(:rollback=> :reraise) do
            # It's gonna be run as a nested transaction inside the containing UoW
            row = self.to_h.merge(parent_identity)
            row.delete(:id)
            id = DB[parent_table.to_sym].insert(row)
            self.id = id
            if defined?(self.class::CHILDREN) and self.class::CHILDREN.is_a?(Array) and !self.class::CHILDREN.empty?
              self.class::CHILDREN.each do |child|
                parent_identity = {"#{parent_name}_id".to_sym=> id}
                child_attr = self.send(child)
                if child_attr.is_a?(Array)
                  unless child_attr.empty?
                    child_attr.each do |obj|
                      self.create_child(obj, parent_identity)
                    end
                  end
                else
                  self.create_child(child_attr, parent_identity)
                end
              end
            end
            id
          end # transaction
        end

        def create_child(obj, parent_identity)
          obj.create(parent_identity)
        end

        # TODO: make work the methods below with Aggregate Roots

        def delete
          check_uow_transaction
          name = self.class.to_s.split('::').last.underscore.downcase
          table = name.pluralize

          DB.transaction(:rollback=> :reraise) do
            DB[table.to_sym].where(id:self.id).delete
          end
        end

        def update
          check_uow_transaction
          name = self.class.to_s.split('::').last.underscore.downcase
          table = name.pluralize

          DB.transaction(:rollback=> :reraise) do
            row = self.to_h
            DB[table.to_sym].where(id:self.id).update(row)
          end
        end

        def reload
        end

        private
        def check_uow_transaction
          raise RuntimeError, "Invalid Transaction" if self.transactions.empty?
        end
      end
    end
  end
end