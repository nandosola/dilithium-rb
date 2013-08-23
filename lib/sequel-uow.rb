require 'uow/exceptions'
require 'uow/uuid_generator'
require 'uow/object_tracker'
require 'uow/transaction'
require 'uow/registry'

require 'sequel'
# Load plugins/extensions for every model
Sequel.extension :inflector

require 'mapper'
require 'repository'
require 'base_entity'