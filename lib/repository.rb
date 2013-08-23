module Repository
  module Sequel
    DB = $database
    module ClassFinders

      def self.extended(base)
        base.instance_eval do

          def fetch_by_id(id, eager=true)
            root_name = self.to_s.split('::').last.downcase
            root_table = root_name.pluralize
            found_h = DB[root_table.to_sym].where(id:id).all.first
            unless found_h.nil?
              root_obj = self.new(found_h)
              root_obj.attach_children if eager
              root_obj
            else
              nil
            end
          end

          def fetch_all(eager=true)
            table = self.to_s.split('::').last.downcase.pluralize
            found_h = DB[table.to_sym]
            unless found_h.empty?
              found_h.map do |reg|
                self.fetch_by_id(reg[:id], eager)
              end
            else
              []
            end
          end

        end
      end
    end

    module InstanceFinders

      def self.included(base)
        base.class_eval do

          def attach_children
            if defined?(self.class::CHILDREN) and self.class::CHILDREN.is_a?(Array) and !self.class::CHILDREN.empty?
              parent_name = self.class.to_s.split('::').last.downcase
              self.class::CHILDREN.each do |child_name|
                children_h = DB[child_name].where("#{parent_name}_id".to_sym=> self.id).all
                unless children_h.nil?
                  if children_h.is_a?(Array)
                    unless children_h.empty?
                      children_h.each do |child_h|
                        attach_child(self, child_name, child_h)
                      end
                    end
                  else
                    attach_child(self, child_name, children_h)
                  end
                end
              end
            end
          end

          def attach_child(parent_obj, child_name, child_h)
            child_obj = parent_obj.send("make_#{child_name.to_s.singularize}".to_sym, child_h)
            child_obj.attach_children
          end

        end
      end
    end
  end
end