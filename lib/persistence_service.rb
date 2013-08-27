require 'mapper'
require 'repository'

module PersistenceService
  class Sequel
    def self.db=(db)
      Mapper::Sequel.const_set(:DB, db)
      Repository::Sequel.const_set(:DB, db)
    end
  end
end