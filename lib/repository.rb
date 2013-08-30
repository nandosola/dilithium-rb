module Repository

  # TODO
  #   Use inside a Repository class. Access it as QueryObject (Repository.query(class, criteria)
  #   or via SpecificationPattern (http://devlicio.us/blogs/casey/archive/2009/03/02/ddd-the-specification-pattern.aspx)
  # TODO caching layer
  # TODO get map inside Repository

  module Sequel

    module ClassFinders

      def self.extended(base)
        base.instance_eval do

          def fetch_by_id(id, eager=true)
            root_name = self.to_s.split('::').last.underscore.downcase
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
            unless self.class.child_references.empty?
              parent_name = self.class.to_s.split('::').last.underscore.downcase
              self.class.child_references.each do |child_name|
                children = DB[child_name].where("#{parent_name}_id".to_sym=> self.id).all
                unless children.nil?
                  if children.is_a?(Array)
                    unless children.empty?
                      children.each do |child_h|
                        attach_child(self, child_name, child_h)
                      end
                    end
                  else
                    attach_child(self, child_name, children)
                  end
                end
              end
            end
          end

          def attach_child(parent_obj, child_name, child_h)
            child_h.delete_if{|k,v| k.to_s.end_with?('_id')}
            method = "make_#{child_name.to_s.singularize}"
            child_obj = parent_obj.send(method.to_sym, child_h)
            child_obj.attach_children
          end

        end
      end
    end
  end
end