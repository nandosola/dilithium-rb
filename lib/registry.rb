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
    def find_units_of_work(obj)
      @@registry.reduce({}) do |m,(uuid,uow)|
        if obj === uow.fetch_object(obj)
          m[uuid.to_s] = uow
        else
          m
        end
      end
    end
    alias_method :find_uows, :find_units_of_work
    # TODO create/read file for each UOW
    def marshall_dump
    end
    def marshall_load
    end
  end

  module FinderService
    module ClassMethods
      def self.extended(base_class)
        base_class.instance_eval {
          def fetch_from_registry(uuid, obj_id)
            uow = Registry.instance[uuid.to_sym]
            (uow.nil?) ? nil : uow.fetch_object_by_id(base_class, obj_id)
          end
        }
      end
    end
    module InstanceMethods
      def units_of_work
        Registry.instance.find_uows(self)
      end
    end
  end

end
