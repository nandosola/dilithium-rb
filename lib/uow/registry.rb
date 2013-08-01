require 'singleton'

module UnitOfWork
  module TransactionRegistry

    # TODO maybe the registry should store nodename/class/id/transaction/state - this would allow easier distribution
    class Registry
      class SearchResult
        attr_reader :transaction, :object, :state
        def initialize(transaction, tracked_object_sr)
          @transaction = transaction
          @object = tracked_object_sr.object
          @state = tracked_object_sr.state
        end
      end

      include Singleton
      def initialize
        @@registry = {}
      end
      def [](tr)
        @@registry[tr]
      end
      def <<(tr)
        @@registry[tr.uuid.to_sym] = tr
      end
      def delete(tr)
        @@registry.delete(tr.uuid.to_sym)
      end
      def find_transactions(obj)
        @@registry.reduce([]) do |m,(uuid,tr)|
          res = tr.fetch_object(obj)
          if !res.nil? && obj === res.object
            m<< SearchResult.new(tr, res)
          else
            m
          end
        end
      end
      # TODO create/read file for each Transaction
      def marshall_dump
      end
      def marshall_load
      end
    end

    module FinderService
      module ClassMethods
        def self.extended(base_class)
          base_class.instance_eval {
            def fetch_from_transaction(uuid, obj_id)
              tr = Registry.instance[uuid.to_sym]
              (tr.nil?) ? nil : TransactionRegistry::Registry::SearchResult.new(tr,
                                                         tr.fetch_object_by_id(self, obj_id))
            end
          }
        end
      end
      module InstanceMethods
        def transactions
          Registry.instance.find_transactions(self)
        end
      end
    end

  end
end
