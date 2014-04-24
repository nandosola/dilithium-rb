# -*- encoding : utf-8 -*-

module Dilithium
  module Repository
    module Sequel
      module EntityClassBuilders

        def self.extended(base)
          base.instance_eval do

            def fetch_by_id(id)
              DefaultFinders.fetch_by_id(self, self.identifier_names.first => id)
            end

            def fetch_all
              DefaultFinders.fetch_all(self)
            end

            def key?(id)
              DefaultFinders.key?(self, self.identifier_names.first => id)
            end

            #TODO Refactor in Reference class
            def fetch_reference_by_id(id)
              Association::LazyEntityReference.new(id, self)
            end

            private

            def resolve_entity_references(in_h)
              self.immutable_references.each do |ref|
                attr = self.attribute_descriptors[ref]
                ref_name = SchemaUtils::Sequel.to_reference_name(attr)
                ref_id = in_h[ref_name]  #TODO change to "_id" here, not at the BasicAttribute
                in_h.delete(ref_name)
                in_h[ref] = ref_id.nil? ? nil : Association::ImmutableEntityReference.new(ref_id, attr.type)
              end
            end

            def resolve_parent(in_h)
              attr = self.attribute_descriptors[self.parent_reference]
              ret = nil

              unless attr.nil? || in_h.has_key?(attr.name)
                ref_name = SchemaUtils::Sequel.to_reference_name(attr)
                if in_h.has_key?(ref_name)
                  ref_id = in_h[ref_name] #TODO change to "_id" here, not at the BasicAttribute
                  ref_value = Association::LazyEntityReference.new(ref_id, attr.type)
                  in_h.delete(ref_name)
                  in_h[attr.name] = ref_value
                  ret = ref_value
                end
              end

              ret
            end

            # FIXME make private again after issue #41 is solved
            public
            def load_object(in_h)
              unless in_h.nil?
                version = SharedVersion.resolve(self, in_h[:id])
                _load_object_helper(in_h, version)
              else
                nil
              end
            end
          end
        end

        private

        def _load_object_helper(in_h, version)
          in_h.delete(:_version_id)
          resolve_entity_references(in_h)
          resolve_parent(in_h) if self.has_parent?  # FIXME Added as a hotfix until issue #41 is solved
          BuilderHelpers.normalize_value_references(self, in_h)
          BuilderHelpers.resolve_extended_generic_attributes(self, in_h)

          obj = self.build(version) do |obj|
            in_h.each do |k, v|
              # FIXME for issue #41
              #   A(root)--ref-> B <-child--C <-child--D(root)
              #
              #   Repository.for(A).where(ref:{id:42})
              #   > <B instance> without C (pruned parent)?
              #   > <B instance> with C as parent/ImmutableEntityReference
              obj.send("#{k}=", v) unless self.attribute_descriptors[k].is_a?(BasicAttributes::ParentReference) ||
                  self.attribute_descriptors[k].is_a?(BasicAttributes::ListReference)
            end
          end

          obj.send(:attach_multi_references)
          obj.send(:_load_children)
          obj
        end
      end

      module EntityInstanceBuilders

        def self.included(base)
          base.class_eval do

            private

            def _load_children
              unless self.class.child_references.empty?
                parent_name = self.class.to_s.split('::').last.underscore.downcase
                self.class.child_references.each do |child_name|
                  children = DB[child_name].where("#{parent_name}_id".to_sym=> self.id).where(active: true).all
                  unless children.nil?
                    if children.is_a?(Array)
                      children.each do |child_h|
                        _load_child(self, child_name, child_h)
                      end
                    else
                      _load_child(self, child_name, children)
                    end
                  end
                end
              end
            end

            def _load_child(parent_obj, child_name, child_h)
              child_class = parent_obj.class.attribute_descriptors[child_name].inner_type
              if child_h.key?(:_type) #Polymorphic children
                active = child_h[:active]
                child_class = child_class.ns.append_to_module_path(child_h[:_type], true)
                child_h = DB[child_h[:_type].to_sym].where(id:child_h[:id]).first
                child_h[:active] = active
              end

              parent_name = child_class.parent_reference
              parent_reference = "#{parent_name}_id".to_sym

              child_h.delete_if {|k,v| k == parent_reference }

              child = child_class.send(:_load_object_helper, child_h, parent_obj._version)
              parent_obj.send(:"add_#{child_name.to_s.singularize}".to_sym, child)
            end

            def attach_multi_references
              references = self.class.multi_references

              references.each do |ref_name|
                intermediate_table = "#{SchemaUtils::Sequel.to_table_name(self)}_#{ref_name}"
                module_path = self.class.to_s.split('::')
                dependent_name = "#{module_path.last.underscore.downcase}_id"
                multi_refs = DB[intermediate_table.to_sym].where(dependent_name.to_sym=>self.id).all

                unless multi_refs.nil?
                  if multi_refs.is_a?(Array)
                    multi_refs.each do |ref_h|
                      attach_reference(self, ref_name, ref_h)
                    end
                  else
                    attach_reference(self, ref_name, multi_refs)
                  end
                end
              end
            end

            def attach_reference(dependent_obj, ref_name, ref_h)
              ref_class = dependent_obj.class.attribute_descriptors[ref_name].inner_type
              ref_module_path = ref_class.to_s.split('::')
              name = if ref_module_path.last == 'Immutable'
                       ref_module_path[-2]
                     else
                       ref_module_path.last
                     end
              ref_attr = "#{name.underscore.downcase}_id".to_sym
              found_ref = ref_class.send(:fetch_reference_by_id, ref_h[ref_attr])

              method = "add_#{ref_name.to_s.singularize}"
              dependent_obj.send(method.to_sym, found_ref)
            end

          end
        end
      end


    end
  end
end
