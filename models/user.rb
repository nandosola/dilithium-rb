require 'lib/repository'
require 'lib/unitofwork'
require 'lib/registry'

class User < Sequel::Model
  extend Sequel::UserRepository
  extend UnitOfWorkRegistry::FinderService::ClassMethods
  include UnitOfWorkRegistry::FinderService::InstanceMethods
end

