require 'mapper'
require 'repository'
require 'association'

module PersistenceService
  class Sequel
    def self.db=(db)
      Mapper::Sequel.const_set(:DB, db)
      Repository::Sequel.const_set(:DB, db)
      Association::Sequel.const_set(:DB, db)
    end
  end
end