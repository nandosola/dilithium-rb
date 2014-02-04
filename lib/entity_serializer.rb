require_relative 'database_utils'

class EntitySerializer

  def self.to_hash(entity, opts={})
    h = {}
    skip_class = opts[:without]

    case entity
      when Association::LazyEntityReference
        h[:"#{entity.type.to_s.split('::').last.underscore.downcase.singularize}_id"] = entity.id
      else
        entity.class.attribute_names.each do |attr|
          attr_value = entity.send(attr.to_sym)
          next if !skip_class.nil? && attr_value.is_a?(skip_class)
          # TODO: uncomment when BasicEntityBuilder is ready
          # attr_type = entity.class.attribute_descriptor[attr_name]
          # attr_value = attr_type.to_generic_type(attr_value) if attr_type.instance_of?(BasicAttributes::ExtendedGenericAttribute)
          h[attr] =  attr_value
        end
    end
    h
  end

  def self.to_nested_hash(entity, opts={})
    entity_h = to_hash(entity, opts)

    entity_h.each do |attr, value|
      unless entity.is_a?(Association::LazyEntityReference)
        attr_type = entity.class.attribute_descriptors[attr]

        case attr_type
          when BasicAttributes::ParentReference
            entity_h.delete(attr)
          when BasicAttributes::ImmutableReference, BasicAttributes::ImmutableMultiReference
            entity_h[attr] = value
          when BasicAttributes::ChildReference, BasicAttributes::MultiReference
            entity_h[attr] = value.map { |ref| to_nested_hash(ref, opts) } unless value.nil?
          when BasicAttributes::Version
            entity_h[attr] = to_nested_hash(value, opts) unless value.nil?
        end
      end

    end

    entity_h
  end

  def self.to_row(entity, parent_id=nil)
    row = {}
    entity_h = to_hash(entity)
    if parent_id
      parent_ref = "#{entity.class.parent_reference}_id".to_sym
      entity_h[parent_ref] = parent_id if parent_id
    end
    entity_h.each do |attr,value|
      attr_type = entity.class.attribute_descriptors[attr]
      unless [BasicAttributes::Version, BasicAttributes::ChildReference, BasicAttributes::ParentReference,
              BasicAttributes::MultiReference, BasicAttributes::ImmutableMultiReference].include?(attr_type.class)
        case attr_type
          when BasicAttributes::ImmutableReference
            row[DatabaseUtils.to_reference_name(attr_type)] = value.nil? ? attr_type.default : value.id
          else
            row[attr] = value
        end
      end
    end
    row
  end

  def self.strip_key_from_hash(a_hash, key)
    if a_hash.is_a?(Hash)
      a_hash.inject({}) do |m, (k,v)|
        if v.is_a?(Array)
          m[k] = v.map{|y| strip_key_from_hash(y, key)}
        else
          m[k] = strip_key_from_hash(v, key) unless key == k
        end
        m
      end
    else
      a_hash
    end
  end

end
