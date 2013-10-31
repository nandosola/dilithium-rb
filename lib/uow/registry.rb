require 'singleton'

module UnitOfWork
  module TransactionRegistry

    # TODO maybe the registry should store nodename/class/id/transaction/state - this would allow easier distribution
    class Registry
      include TransactionRegistryExceptions

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
        @@registry = Hash.new do |hash,key|
                      raise TransactionNotFound.new()
                    end
      end
      def [](tr_uuid)
        @@registry[tr_uuid.to_sym]
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
          if !res.nil? && obj == res.object
            m<< SearchResult.new(tr, res)
          else
            m
          end
        end
      end
      def each_entity(tr_uuid)
        tr = @@registry[tr_uuid.to_sym]
        tr.fetch_all_objects.each do |entity|
          yield(SearchResult.new(tr,entity))
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
            def fetch_from_transaction(uuid, obj_id=nil)
              begin
                tr = Registry.instance[uuid.to_sym]
                if obj_id.nil?
                  entities = tr.fetch_object_by_class(self)
                  entities.each { |entity| yield(TransactionRegistry::Registry::SearchResult.new(tr, entity)) }
                else
                  TransactionRegistry::Registry::SearchResult.new(tr,tr.fetch_object_by_id(self, obj_id))
                end
              rescue TransactionRegistryExceptions::TransactionNotFound
                nil
              end
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
