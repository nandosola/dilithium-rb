# -*- encoding : utf-8 -*-

module Dilithium
  module Repository
    # TODO
    #   Use inside a Repository class. Access it as QueryObject (Repository.query(class, criteria)
    #   or via SpecificationPattern (http://devlicio.us/blogs/casey/archive/2009/03/02/ddd-the-specification-pattern.aspx)
    # TODO caching layer
    # TODO get map inside Repository

    # Repository factory
    # Returns a repository for the given type. The repository should at the very least support fetch_by_id and
    # fetch_all
    #
    # Parameters:
    #  type: A subclass of BaseValue or BaseEntity
    def self.for(type)
      if type < BaseValue
        Sequel::ValueRepository.new(type)
      else
        #TODO Refactor to have a real BaseEntityRepository and possibly a ReferenceRepository. Not done yet to
        # preserve backwards compatibility and because it should be part of the implementation of #41 (Move all
        # finders from Entities to the Repository)
        # Sequel::EntityRepository.new
        type
      end
    end


    module Sequel
      module DefaultFinders
        def self.fetch_by_id(domain_class, id_h)
          superclasses = PersistenceService.superclass_list(domain_class)
          i_root = superclasses.last
          root_table = PersistenceService.table_for(i_root)
          root_db = DB[root_table]
          root_h = root_db.where(id_h).first

          raise PersistenceExceptions::NotFound.new(id_h, domain_class) if root_h.nil?

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

          type.send(:load_object, merged_h)
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

        def self.key?(domain_class, id_h)
          root_class = PersistenceService.inheritance_root_for(domain_class)
          root_table = PersistenceService.table_for(root_class)
          DB[root_table].where(id_h).count > 0
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

    end
  end
end