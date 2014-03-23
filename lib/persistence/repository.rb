# -*- encoding : utf-8 -*-

module Dilithium
  module Repository
    # TODO
    #   Use inside a Repository class. Access it as QueryObject (Repository.query(class, criteria)
    #   or via SpecificationPattern (http://devlicio.us/blogs/casey/archive/2009/03/02/ddd-the-specification-pattern.aspx)
    # TODO caching layer
    # TODO get map inside Repository

    class NotFound < Exception
      attr_accessor :id, :type
      def initialize(id, type)
        super("#{type} with ID #{id} not found")
        @id = id
        @type = type
      end
    end

    module Sequel
      module GenericFinders
        def self.fetch_by_id(domain_class, id_h)
          superclasses = PersistenceService.superclass_list(domain_class)
          i_root = superclasses.last
          root_table = PersistenceService.table_for(i_root)
          root_db = DB[root_table]
          root_h = root_db.where(id_h).first

          raise PersistenceExceptions::NotFound, "#{domain_class} with IDs #{id_h} not found" if root_h.nil?

          type = if root_h.nil? || root_h[:_type].nil?
                   domain_class
                 else
                   PersistenceService.class_for(root_h[:_type])
                 end

          key_h = i_root.identifier_names.each_with_object(Hash.new) { |id, h| h[id] = id}

          merged_h = if root_h.nil?
                       nil
                     else
                       query = PersistenceService.superclass_list(type)[0..-2].inject(root_db) do |memo, klazz|
                         memo.join(PersistenceService.table_for(klazz), key_h)
                       end

                       condition_h = id_h.each_with_object(Hash.new) do |(k, v), h|
                         h["#{root_table}__#{k}".to_sym] = v
                       end

                       query.where(condition_h.merge(active:true)).first
                     end

          merged_h.delete(:_type) unless merged_h.nil?

          type.create_object(merged_h)
        end

        def self.fetch_all(domain_class)
          #TODO We do N+1 queries, fix this to get it in a single query
          table = PersistenceService.table_for(domain_class)
          found_h = DB[table]

          if found_h.empty?
            []
          else
            ids = domain_class.identifier_names
            found_h.map do |row|
              id_h = row.select { |k, v| ids.include? k }
              fetch_by_id(domain_class, id_h)
            end
          end
        end
      end

      module BuilderHelpers
        def self.resolve_extended_generic_attributes(klazz, in_h)
          klazz.extended_generic_attributes.each do |gen_attr|
            attr = klazz.attribute_descriptors[gen_attr]
            in_h[gen_attr] = attr.type.new(in_h[attr.name])
          end
        end

      end

      module EntityClassBuilders

        def self.extended(base)
          base.instance_eval do

            def fetch_by_id(id)
              GenericFinders.fetch_by_id(self, self.identifier_names.first => id)
            end

            def fetch_all
              GenericFinders.fetch_all(self)
            end

            #TODO Refactor in Reference class
            def fetch_reference_by_id(id)
              Association::LazyEntityReference.new(id, self)
            end


            def resolve_references(in_h)
              self.immutable_references.each do |ref|
                attr = self.attribute_descriptors[ref]
                ref_name = SchemaUtils::Sequel.to_reference_name(attr)
                ref_id = in_h[ref_name]  #TODO change to "_id" here, not at the BasicAttribute
                ref_value = ref_id.nil? ? nil : in_h[attr.name] = attr.type.fetch_by_id(ref_id)
                in_h.delete(ref_name)
                in_h[ref] = ref_value
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

            def create_object(in_h)
              unless in_h.nil?
                version = SharedVersion.resolve(self, in_h[:id])
                in_h.delete(:_version_id)
                resolve_references(in_h)
                BuilderHelpers.resolve_extended_generic_attributes(self, in_h)
                parent = resolve_parent(in_h)
                root_obj = self.new(in_h, parent, version)
                root_obj.attach_children
                root_obj.attach_multi_references
                root_obj
              else
                nil
              end
            end
          end
        end
      end

      module EntityInstanceBuilders

        def self.included(base)
          base.class_eval do

            def attach_children
              unless self.class.child_references.empty?
                parent_name = self.class.to_s.split('::').last.underscore.downcase
                self.class.child_references.each do |child_name|
                  children = DB[child_name].where("#{parent_name}_id".to_sym=> self.id).where(active: true).all
                  unless children.nil?
                    if children.is_a?(Array)
                      children.each do |child_h|
                        attach_child(self, child_name, child_h)
                      end
                    else
                      attach_child(self, child_name, children)
                    end
                  end
                end
              end
            end

            def attach_child(parent_obj, child_name, child_h)
              child_class = parent_obj.class.attribute_descriptors[child_name].inner_type
              child_class.resolve_references(child_h)
              child_h.delete_if{|k,v| k.to_s.end_with?('_id')}
              method = "make_#{child_name.to_s.singularize}"
              child_obj = parent_obj.send(method.to_sym, child_h)
              child_obj.attach_children
              child_obj.attach_multi_references
            end

            def attach_multi_references
              references = self.class.multi_references + self.class.immutable_multi_references

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
              found_ref = ref_class.fetch_reference_by_id(ref_h[ref_attr])

              method = "add_#{ref_name.to_s.singularize}"
              dependent_obj.send(method.to_sym, found_ref)
            end

          end
        end
      end
    end
  end
end