require 'singleton'

module UnitOfWorkRegistry

  class Registry
    include Singleton
    def initialize
      @@registry = {}
    end
    def [](uow)
      @@registry[uow]
    end
    def <<(uow)
      @@registry[uow.uuid.to_sym] = uow
    end
    def delete(uow)
      @@registry.delete(uow.uuid.to_sym)
    end
    # TODO create/read file for each UOW
    def marshall_dump
    end
    def marshall_load
    end
  end

  module FinderService
    def self.extended(base_class)
      base_class.instance_eval {
        def fetch_from_registry(uuid, obj_id)
          uow = Registry.instance[uuid.to_sym]
          (uow.nil?) ? nil : uow.fetch_object_by_id(base_class, obj_id)
        end
      }
    end
  end

end
