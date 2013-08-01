require 'lib/mapper'
require 'lib/repository'
require 'lib/unit_of_work'

class User < Sequel::Model
  extend Sequel::UserRepository
  extend TransactionRegistry::FinderService::ClassMethods
  include TransactionRegistry::FinderService::InstanceMethods
end

