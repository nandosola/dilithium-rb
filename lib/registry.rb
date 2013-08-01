require 'singleton'

module UnitOfWorkRegistry

  # TODO maybe the registry should store nodename/class/id/UoW/state - this would allow easier distribution
  class Registry
    class RegistrySearchResult
      attr_reader :unit_of_work, :state
      def initialize(uow, st)
        @unit_of_work = uow
        @state = st
      end
    end

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
      @@registry.reduce([]) do |m,(uuid,uow)|
        res = uow.fetch_object(obj)
        if !res.nil? && obj === res.object
          m<< RegistrySearchResult.new(uow, res.state)
        else
          m
        end
      end
    end
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
          def fetch_from_unit_of_work(uuid, obj_id)
            uow = Registry.instance[uuid.to_sym]
            (uow.nil?) ? nil : uow.fetch_object_by_id(self, obj_id)
          end
        }
      end
    end
    module InstanceMethods
      def units_of_work
        Registry.instance.find_units_of_work(self)
      end
    end
  end

end
