require 'database_utils'
require 'ostruct'

module Association
  class ReferenceEntity
    attr_reader :id, :type, :resolved_entity
    def initialize(id, referenced_class, resolver_class)
      @id = id
      @type = referenced_class
      @resolver_class = resolver_class
      @resolved_entity = nil
    end
    def resolve
      # FIXME this should be done via a ResolvedEntity and method objects
      @resolved_entity = OpenStruct.new(@resolver_class.send(:resolve, self))
    end
  end

  class Sequel
    def self.resolve(ref_entity)
      query = {id:ref_entity.id, active:true}
      found_h = DB[DatabaseUtils.to_table_name(ref_entity)].where(query).first
      strip_ids(found_h)
    end
    def self.strip_ids(in_h)
      in_h.delete_if{|k,v| k.to_s =~ /(^|_)id$/}
    end
  end
end