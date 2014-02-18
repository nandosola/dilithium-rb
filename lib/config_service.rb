# -*- encoding : utf-8 -*-
require 'sequel'

# Sequel config
Sequel.extension :inflector
Sequel.datetime_class = DateTime

module Dilithium
  module DatabaseUtils
  end
  module Mapper
    class Sequel
    end
  end
  module Repository
    module Sequel
    end
  end
  class SharedVersion
  end

  module PersistenceService
    class ConfigurationError < Exception; end

    class Sequel
      def self.db=(db)
        DatabaseUtils.const_set(:DB, db)
        Mapper::Sequel.const_set(:DB, db)
        Repository::Sequel.const_set(:DB, db)
        SharedVersion.const_set(:DB, db)
      end
    end

    class Configuration
      def initialize
        @mappers = {}
      end

      def inheritance_mappers(args)
        args.each do |k, v|
          raise ConfigurationError, "Invalid inheritance mapper type #{v}" unless [:class, :leaf].include?(v)
          raise ConfigurationError, "Mapper for class #{k} has already been seet" if @mappers.has_key?(k)

          @mappers[k] = v
        end
      end

      def find_in(map_sym, klazz)
        map = case map_sym
                when :mappers
                  @mappers
                else
                  raise PersistenceService::ConfigurationError, "Unknown configuration map type #{map_sym}"
              end

        raise PersistenceService::ConfigurationError, 'The PersistenceService can only be configured for BaseEntities' unless klazz <= BaseEntity
        if map.has_key?(klazz)
          map[klazz]
        else
          str = klazz.to_s
          sym = str.to_sym

          if map.has_key?(sym)
            map[klazz] = map.delete(sym)
          else
            path = str.split('::')
            cls = path.reduce(Object) { |m, c| m.const_get(c.to_sym) }
            map[klazz] = find_in(map_sym, cls.superclass)
          end
        end

        map[klazz]
      end
    end

    @configuration = Configuration.new

    def self.configure
      raise ConfigurationError, 'Trying to configure an already-configured PersistenceService' if @configured
      yield @configuration
      @configured = true
    end

    def self.mapper_for(klazz)
      @configuration.find_in(:mappers, klazz)
    end
  end
end
