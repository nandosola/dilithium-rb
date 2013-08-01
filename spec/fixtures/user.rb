require 'lib/mapper'
require 'lib/repository'
require 'lib/unit_of_work'

module Repository::Sequel
  module User
    include Base

    def fetch_by_email email
      self[email:email]
    end
    def fetch_by_name name
      self[name:name]
    end
  end
end

class User < Sequel::Model
  extend Repository::Sequel::User
  extend TransactionRegistry::FinderService::ClassMethods
  include TransactionRegistry::FinderService::InstanceMethods
end

