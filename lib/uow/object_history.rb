# -*- encoding : utf-8 -*-
module UnitOfWork
  # CAVEAT: this is not distribution-friendly. object_id should use 'nodename' as well
  class ObjectHistory
    def initialize
      # TODO save object state as well
      @object_ids = {}
    end
    def <<(obj)
      # TODO the 'deep clone' part should be moved to a Serialization Mixin
      oid = obj.object_id.to_s.to_sym
      @object_ids[oid] = Array(@object_ids[oid]) << Marshal.load(Marshal.dump(obj))  # deep-clones references too
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
