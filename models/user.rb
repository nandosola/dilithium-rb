require 'lib/repository'
require 'lib/unitofwork'

class User < Sequel::Model
  extend Sequel::UserRepository
  include UnitOfWorkMixin
end

