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
    class Sequel
      def self.db=(db)
        SchemaUtils::Sequel.const_set(:DB, db)
        Mapper::Sequel.const_set(:DB, db)
        Repository::Sequel.const_set(:DB, db)
        SharedVersion.const_set(:DB, db)
      end
    end
  end
end
