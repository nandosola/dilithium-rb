require 'uow/exceptions'
require 'uow/uuid_generator'
require 'uow/object_tracker'
require 'uow/transaction'
require 'uow/registry'

require 'sequel'

# Sequel config
Sequel.extension :inflector
Sequel.datetime_class = DateTime

require 'persistence_service'
require 'base_entity'
