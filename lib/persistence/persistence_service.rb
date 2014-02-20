module Dilithium
  module PersistenceService
    class ConfigurationError < Exception; end

    class Configuration
      def initialize
        @mappers = {}
        @tables = {}
        @table_classes = {}
      end

      def inheritance_mappers(args)
        args.each do |k, v|
          raise ConfigurationError, "Invalid inheritance mapper type #{v}" unless [:class, :leaf].include?(v)
          raise ConfigurationError, "Mapper for class #{k} has already been set" if @mappers.has_key?(k)

          @mappers[k] = v
        end
      end

      def find_in(map_sym, klazz, allow_redefines, include_inherited = true)
        map = case map_sym
                when :mappers
                  @mappers
                when :tables
                  @tables
                else
                  raise PersistenceService::ConfigurationError, "Unknown configuration map type #{map_sym}"
              end

        raise PersistenceService::ConfigurationError, "#{klazz} is not a BaseEntity. The PersistenceService can only be configured for BaseEntities." unless klazz <= BaseEntity
        if map.has_key?(klazz)
          map[klazz]
        else
          str = klazz.to_s
          sym = str.to_sym

          if map.has_key?(sym)
            if ! allow_redefines &&
              klazz.superclass != BaseEntity &&
              klazz != BaseEntity &&
              find_in(map, klazz.superclass, allow_redefines) != sym

              raise PersistenceService::ConfigurationError
            end

            map[klazz] = map.delete(sym)
          elsif include_inherited
            path = str.split('::')
            cls = path.reduce(Object) { |m, c| m.const_get(c.to_sym) }
            map[klazz] = find_in(map_sym, cls.superclass, allow_redefines)
          end
        end

        map[klazz]
      end

      def class_for(table)
        @table_classes[table.to_sym]
      end

      def add_table_for_class(klazz, table=nil)
        table ||= default_table_name(klazz)

        unless @tables[klazz].nil? || @tables[klazz] == table and
          @table_classes[table].nil? || @table_classes[table] == klazz
          raise PersistenceService::ConfigurationError, "Illegal redefinition of table-class association. Old class: #{@table_classes[table]}, table: #{@tables[klazz]}. New class: #{klazz}, table: #{table}"
        end

        @tables[klazz] = table
        @table_classes[table] = klazz
      end

      private

      def default_table_name(klazz)
        path = klazz.to_s.split('::')
        last = if path.last == 'Immutable'
                 path[-2]
               else
                 path.last
               end

        last.underscore.downcase.pluralize.to_sym
      end
    end

    @configuration = Configuration.new
    @inheritance_roots = {}

    def self.configure
      raise ConfigurationError, 'Trying to configure an already-configured PersistenceService' if @configured
      yield @configuration
      @configured = true
    end

    def self.mapper_for(klazz)
      begin
        @configuration.find_in(:mappers, klazz, false)
      rescue ConfigurationError
        raise ConfigurationError, "Not allowed to redefine the mapper type for entities that are not direct subclasses of Dilithium::BaseEntity. Offending class: #{klazz}"
      end
    end

    def self.table_for(klazz)
      @configuration.find_in(:tables, klazz, false, false)
    end

    def self.class_for(table)
      @configuration.class_for(table)
    end

    def self.add_table(klazz, table = nil)
      @configuration.add_table_for_class(klazz, table)
    end

    def self.is_inheritance_root?(klazz)
      klazz.superclass == BaseEntity || mapper_for(klazz) == :leaf
    end

    def self.inheritance_root_for(klazz)
      superclass_list(klazz).last
    end

    def self.superclass_list(klazz)
      @inheritance_roots[klazz] ||= klazz.ancestors.inject([]) do |memo, c|
        memo << c if c < BaseEntity
        break memo if is_inheritance_root?(c)
        memo
      end
    end
  end
end