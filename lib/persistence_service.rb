# -*- encoding : utf-8 -*-
require 'sequel'

# Sequel config
Sequel.extension :inflector
Sequel.datetime_class = DateTime

require 'mapper'
require 'repository'
require 'association'

module PersistenceService
  class Sequel
    def self.db=(db)
      Mapper::Sequel.const_set(:DB, db)
      Repository::Sequel.const_set(:DB, db)
    end
  end
end
