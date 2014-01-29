require 'database_utils'

module Association
  class LazyEntityReference
    attr_reader :type, :id

    def initialize(id, referenced_class, version = nil, resolved_entity = nil)
      raise ArgumentError, 'Cannot initialize a LazyEntityReference with both id and resolved_entity' \
        unless resolved_entity.nil? || (id.nil? && resolved_entity.id.nil?)
      raise ArgumentError, 'Must provide either a resolved_entity or an id and referenced_class' \
        if (resolved_entity.nil? && (id.nil? || referenced_class.nil?)) || (! resolved_entity.nil? && ! id.nil?)

      @id = id
      @type = referenced_class
      @resolved_entity = resolved_entity
      @_version = if @id.nil?
                    resolved_entity._version
                  else
                    @type.fetch_version_for_id(@id)
                  end

      resolved_entity.add_observer(self) if resolved_entity && resolved_entity.id.nil?
    end

    #TODO Do the fetch_by_id on the root
    #TODO Rename resolve to resolve!
    def resolve
      @_version ||= @type.fetch_version_for_id(@id)
      @resolved_entity ||= @type.fetch_by_id(@id)
    end

    def resolved_entity
      resolve
      @resolved_entity
    end

    def ==(other)
      other.class == self.class &&
        @id == other.id &&
        @type == other.type &&
        _version == other._version
    end

    # From the Observable module, update the reference's ID when the original's PK changes
    def update(original, attr_name, value)
      @id = value if attr_name == DomainObject.pk
    end
  end

  class ImmutableEntityReference < LazyEntityReference
    def initialize(id, referenced_class, resolved_entity = nil)
      super
      @original_entity = resolved_entity
      @resolved_entity = resolved_entity.immutable if resolved_entity
    end

    def self.create(entity)
      case entity
        when NilClass
          nil
        when Association::ImmutableEntityReference
          entity
        when BaseEntity::Immutable
          Association::ImmutableEntityReference.new(entity.id, entity.class.const_get(:MUTABLE_CLASS))
        when BaseEntity
          if entity.id.nil?
            Association::ImmutableEntityReference.new(nil, entity.class, entity)
          else
            Association::ImmutableEntityReference.new(entity.id, entity.class)
          end
        else
          raise ArgumentError, 'Assignment of a non-BaseEntity to a Reference'
      end
    end

    def resolve
      @resolved_entity = super.immutable
    end
  end
end
