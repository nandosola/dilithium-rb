require 'database_utils'
require 'ostruct'

module Association
  #TODO This should really be an Attribute

  class ReferenceEntity
    attr_reader :id, :type, :resolved_entity
    def initialize(id, referenced_class)
      @id = id
      @type = referenced_class
      @resolved_entity = nil
    end
    def resolve
      @resolved_entity = @type.fetch_by_id(@id)
    end
  end
end