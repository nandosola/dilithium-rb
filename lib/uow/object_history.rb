# -*- encoding : utf-8 -*-
module Dilithium
  module UnitOfWork
    class ObjectHistory
      def initialize
        @object_ids = {}
      end
      def <<(marshaled_state)
        oid = marshaled_state.obj_id
        @object_ids[oid] = Array(@object_ids[oid]) << marshaled_state
      end
      def delete(obj)
        oid = obj.object_id.to_s.to_sym
        @object_ids.delete(oid)
      end
      def [](oid)
        # TODO return iterator
        @object_ids[oid.to_s.to_sym]
      end
    end
  end
end
