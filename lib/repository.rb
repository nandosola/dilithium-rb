require 'reference_entity'

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

          def fetch_by_id(id)
            root_name = self.to_s.split('::').last.underscore.downcase
            root_table = root_name.pluralize
            found_h = DB[root_table.to_sym].where(id:id).where(active: true).all.first
            unless found_h.nil?
              self.resolve_value_references(found_h)
              root_obj = self.new(found_h)
              root_obj.attach_children
              root_obj.attach_multi_references
              root_obj
            else
              nil
            end
          end

          def fetch_all
            table = self.to_s.split('::').last.downcase.pluralize
            found_h = DB[table.to_sym]
            unless found_h.empty?
              found_h.map do |reg|
                self.fetch_by_id(reg[:id])
              end
            else
              []
            end
          end

          #TODO Refactor in reference repository
          def fetch_reference_by_id(id)
            ReferenceEntity.new(id, self)
          end

          def resolve_value_references(in_h)
            if self.has_value_references?
              self.value_references.each do |ref|
                attr = self.class_variable_get(:'@@attributes')[ref]
                ref_id = in_h[attr.reference]  #TODO change to "_id" here, not at the BasicAttribute
                ref_value = ref_id.nil? ? nil : in_h[attr.name] = attr.type.fetch_by_id(ref_id)
                in_h.delete(attr.reference)
                in_h[ref] = ref_value
              end
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
                children = DB[child_name].where("#{parent_name}_id".to_sym=> self.id).where(active: true).all
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
            child_class =  parent_obj.class.reference_type(child_name)
            child_class.resolve_value_references(child_h)
            child_h.delete_if{|k,v| k.to_s.end_with?('_id')}
            method = "make_#{child_name.to_s.singularize}"
            child_obj = parent_obj.send(method.to_sym, child_h)
            child_obj.attach_children
          end

          def attach_multi_references
            unless self.class.multi_references.empty?
              self.class.multi_references.each do |ref_name|
                intermediate_table = "#{Mapper::Sequel.to_table_name(self)}_#{ref_name}"
                module_path = self.class.to_s.split('::')
                dependent_name = "#{module_path.last.underscore.downcase}_id"
                multi_refs = DB[intermediate_table.to_sym].where(dependent_name.to_sym=>self.id).all

                unless multi_refs.nil?
                  if multi_refs.is_a?(Array)
                    unless multi_refs.empty?
                      multi_refs.each do |ref_h|
                        attach_reference(self, ref_name, ref_h)
                      end
                    end
                  else
                    attach_reference(self, ref_name, multi_refs)
                  end
                end
              end
            end
          end

          def attach_reference(dependent_obj, ref_name, ref_h)
            ref_class = dependent_obj.class.reference_type(ref_name)
            ref_attr = "#{ref_name.to_s.singularize}_id".to_sym
            # TODO should all references inbetween aggregates be lazy??
            found_ref = ref_class.fetch_reference_by_id(ref_h[ref_attr])

            method = "#{ref_name}<<"
            dependent_obj.send(method.to_sym, found_ref)
          end

        end
      end
    end
  end
end
