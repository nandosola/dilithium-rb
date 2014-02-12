require 'database_utils'

module Association
  class LazyEntityReference
    attr_reader :type, :id, :_version

    #TODO Should we also create delegate methods to call the resolved_entity instead of having to use ref.resolved_entity.foo?
    def initialize(id, referenced_class, version = nil, resolved_entity = nil)
      if resolved_entity.nil?
        if id.nil? || referenced_class.nil?
          raise ArgumentError, 'Must provide either a resolved_entity or an id and referenced_class'
        end

        @id = id
        @type = referenced_class
        @_version = @type.fetch_version_for_id(@id)
      else
        raise ArgumentError 'Cannot initialize a LazyEntityReference with both id and resolved_entity' unless id.nil?

        @resolved_entity = resolved_entity
        @id = resolved_entity.id
        @type = resolved_entity.class
        @_version = resolved_entity._version

        resolved_entity.add_observer(self) if resolved_entity.id.nil?
      end
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
    alias_method :get, :resolved_entity

    def ==(other)
      other.class == self.class &&
        @id == other.id &&
        @type == other.type &&
        @_version == other._version
    end

    # From the Observable module, update the reference's ID when the original's PK changes
    def update(original, attr_name, value)
      @id = value if attr_name == DomainObject.pk
    end
  end

  class ImmutableEntityReference < LazyEntityReference
    def initialize(id, referenced_class, version = nil, resolved_entity = nil)
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
          Association::ImmutableEntityReference.new(nil, nil, nil, entity)
        else
          raise ArgumentError, 'Assignment of a non-BaseEntity to a Reference'
      end
    end

    def resolve
      @original_entity ||= super
      @resolved_entity = @original_entity.immutable
    end

    def resolved?
      @original_entity.nil? || @resolved_entity.nil?
    end
  end
end
