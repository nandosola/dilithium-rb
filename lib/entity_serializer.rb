class EntitySerializer

  def self.to_hash(entity)
    h = {}

    if entity.is_a?(ReferenceEntity)
      h[:"#{entity.type.to_s.split('::').last.downcase.singularize}_id"] = entity.id
    else
      entity.instance_variables.each do |attr|
        attr_name = attr.to_s[1..-1].to_sym
        attr_value = entity.instance_variable_get(attr)
        h[attr_name] =  attr_value
      end
    end
    h
  end

  def self.to_nested_hash(entity)
    entity_h = to_hash(entity)

    entity_h.each do |attr, value|

      unless entity.is_a?(ReferenceEntity)
        attr_type = entity.class.class_variable_get(:'@@attributes')[attr]

        case attr_type
          when BasicAttributes::ChildReference, BasicAttributes::MultiReference
            entity_h[attr] = Array.new
            value.each do |ref|
              entity_h[attr] << to_nested_hash(ref)
            end
          when BasicAttributes::ValueReference
            entity_h[attr] = to_nested_hash(value) unless value.nil?
          when BasicAttributes::ParentReference
            entity_h.delete(attr)
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
      attr_type = entity.class.class_variable_get(:'@@attributes')[attr]
      unless [BasicAttributes::ChildReference, BasicAttributes::ParentReference,
              BasicAttributes::MultiReference].include?(attr_type.class)
        if attr_type.is_a?(BasicAttributes::ValueReference)
          row[attr_type.reference] = value.nil? ? attr_type.default : value.id
        else
          row[attr] = value
        end
      end
    end
    row
  end

end