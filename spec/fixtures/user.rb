require 'lib/sequel-uow'

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
  extend UnitOfWork::TransactionRegistry::FinderService::ClassMethods
  include UnitOfWork::TransactionRegistry::FinderService::InstanceMethods
end

