# -*- encoding : utf-8 -*-
module Dilithium
  class EntitySerializer

    def self.to_hash(entity, opts={})
      h = {}
      skip_class = opts[:without]

      case entity
        when Association::LazyEntityReference
          h[:id] = entity.id
        else
          entity.class.attribute_names.each do |attr|
            attr_value = entity.send(attr.to_sym)
            if entity.class.attributes.find{|x| attr.to_sym == x.name && x.type < Dilithium::BasicAttributes::WrappedInteger}
              attr_value = attr_value.nil? ? nil : attr_value.to_i
            end

            next if !skip_class.nil? && attr_value.is_a?(skip_class)

            h[attr] =  attr_value
          end
      end

      unless ::Dilithium::SharedVersion == skip_class || entity.is_a?(::Dilithium::BaseValue)
        h[:_version] = entity._version.to_h
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
            when BasicAttributes::ImmutableReference
              entity_h[attr] = Association::ImmutableEntityReference.create(value) unless value.nil?
            when BasicAttributes::ImmutableMultiReference
              entity_h[attr] = value.map do |v|
                Association::ImmutableEntityReference.create(v) unless v.nil?
              end
            when BasicAttributes::ChildReference, BasicAttributes::MultiReference
              entity_h[attr] = value.map { |ref| to_nested_hash(ref, opts) } unless value.nil?
            when BasicAttributes::ValueReference
              entity_h[attr] = to_hash(value)
          end
        end
      end

      entity_h
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
end
