module Dilithium
  module Repository
    module Sequel

      module BuilderHelpers
        def self.normalize_value_references(klazz, in_h)
          klazz.value_references.each do |ref|
            attr = klazz.attribute_descriptors[ref]
            keys = attr.type.identifier_names.map do |identifier|
              key = "#{ref}_#{identifier}".to_sym
              in_h.delete(key)
            end

            in_h[ref] = Repository.for(attr.type).fetch_by_id(*keys)
          end
        end
      end

      module ValueClassBuilders
        def self.extended(base)
          base.instance_eval do
            def load_object(in_h)
              if in_h.nil?
                nil
              else
                #TODO Uncomment when values can have references
                #resolve_entity_references(in_h)
                #BuilderHelpers.normalize_value_references(self, in_h)
                BuilderHelpers.resolve_extended_generic_attributes(self, in_h)

                obj = self.build do |obj|
                  in_h.each do |k, v|
                    obj.send("#{k}=", v) unless self.attribute_descriptors[k].is_a? BasicAttributes::ListReference
                  end
                end

                #TODO Uncomment when values can have references
                #obj.send(:attach_multi_references)
                obj
              end
            end
          end
        end
      end

      class ValueRepository
        def fetch_by_id(*args)
          raise ArgumentError, "wrong number of arguments (#{args.length} for #{@type.identifier_names.length})" unless args.length == @type.identifier_names.length

          condition_h = Hash[@type.identifier_names.zip(args)]
          condition_h.delete_if{|k,v| nil == v}
          condition_h.empty? ? nil : DefaultFinders.fetch_by_id(@type, condition_h)
          # TODO NullReference.new(@type) is definitely a good idea
        end

        def fetch_by_phantomid(phantom_id)
          table = PersistenceService.table_for(@type)
          res_h = DB[table].select(*@type.identifier_names).where(:_phantomid=>phantom_id.to_i).first
          fetch_by_id(res_h.values)
        end

        def fetch_all
          DefaultFinders.fetch_all(@type)
        end

        def exists?(value_object)
          identifiers = value_object.class.identifier_names.map{|attr| value_object.send(attr.to_sym)}
          key?(*identifiers)
        end

        def key?(*args)
          raise ArgumentError, "wrong number of arguments (#{args.length} for #{@type.identifier_names.length})" unless args.length == @type.identifier_names.length

          condition_h = Hash[@type.identifier_names.zip(args)]
          DefaultFinders.key?(@type, condition_h) ||
            # handle all values for *all* composite PK attributes set to nil
            @type.identifiers.reduce(true) do |m,attr|
              id = attr[:identifier]
              m && condition_h[id].nil? && condition_h.include?(id)
            end
        end

        private

        def initialize(type)
          raise ArgumentError "#{type} is not a descendant of BaseValue" unless type < BaseValue
          @type = type
        end
      end
    end
  end
end