require 'database_utils'

module Association
  class LazyEntityReference
    attr_reader :id, :type, :resolved_entity, :_version

    def initialize(id, referenced_class)
      @id = id
      @type = referenced_class
      @resolved_entity = nil
      @_version = if @id.nil?
                    nil
                  else
                    @type.fetch_version_for_id(@id)
                  end
    end

    #TODO Do the fetch_by_id on the root
    #TODO Change resolved_entity to automatically call resolve (and rename resolve to resolve!)
    def resolve
      @version = @type.fetch_version_for_id(@id)
      @resolved_entity = @type.fetch_by_id(@id)
    end

    def ==(other)
      other.class == self.class &&
        @id == other.id &&
        @type == other.type &&
        _version == other._version
    end
  end

  class ImmutableEntityReference < LazyEntityReference
    def self.create(entity)
      case entity
        when NilClass
          nil
        when Association::ImmutableEntityReference
          entity
        when Association::LazyEntityReference
          #TODO MCR Remove when removing entity references
          Association::ImmutableEntityReference.new(entity.id, entity.type)
        when BaseEntity::Immutable
          Association::ImmutableEntityReference.new(entity.id, entity.class.const_get(:MUTABLE_CLASS))
        else
          Association::ImmutableEntityReference.new(entity.id, entity.class)
      end
    end

    def resolve
      @resolved_entity = super.immutable
    end
  end
end
