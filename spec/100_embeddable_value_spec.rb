# -*- encoding : utf-8 -*-
require_relative 'spec_base'
require_relative 'fixtures/embeddable_value'

describe 'An embeddable value' do
  it 'should fail if mixed into a non-BaseEntity' do
    expect {
      module Name
        extend EmbeddableValue
        attribute :name, String
      end

      class NonBaseEntity
        include Name
      end
    }.to raise_error(ArgumentError)
  end

  it 'should contain the proper attribute descriptors' do
    attr = AuditInfo.instance_variable_get(:@attributes)

    expect(attr.size).to eq(5)

    %w(created_on last_updated_on).each do |att|
      name = att.to_sym
      expect(attr[name]).to be_a(BasicAttributes::GenericAttribute)
      expect(attr[name].name).to eq(name)
      expect(attr[name].type).to eq(DateTime)
    end

    %w(created_by last_updated_by).each do |att|
      name = att.to_sym
      expect(attr[name]).to be_a(BasicAttributes::ImmutableReference)
      expect(attr[name].name).to eq(name)
      expect(attr[name].type).to eq(User)
    end

    expect(attr[:update_history]).to be_a(BasicAttributes::ImmutableMultiReference)
    expect(attr[:update_history].name).to eq(:update_history)
    expect(attr[:update_history].inner_type).to eq(User)
  end
end

describe 'An model which embeds a value' do
  it 'should contain the proper attribute descriptors' do
    resource_attr = Resource.instance_variable_get(:@attributes)
    audit_attr = AuditInfo.instance_variable_get(:@attributes)

    audit_attr.each do |k, v|
      expect(resource_attr[k]).to eq(v)
    end
  end

  it 'should not allow a BaseEntity to define attributes defined in an EmbeddableValue' do
    expect {
      module Name
        extend EmbeddableValue
        attribute :name, String
      end

      class Duplicate < BaseEntity
        include Name

        attribute :name, String
      end
    }.to raise_error(ArgumentError)
  end

  it 'should not allow a BaseEntity to extend an EmbeddableValue which redefines already-defined attributes' do
    expect {
      module Name
        attribute :name, String
        extend EmbeddableValue
      end

      class Duplicate < BaseEntity
        include Name

        attribute :name, String
      end
    }.to raise_error(ArgumentError)
  end

  it 'should contain the proper attribute accessors' do
    resource = Resource.build
    attr = AuditInfo.instance_variable_get(:@attributes)

    attr.keys.each do |k|
      expect(resource).to respond_to(:"#{k}")
      if attr[k].is_a? BasicAttributes::ImmutableMultiReference
        expect(resource).to respond_to(:"add_#{k.to_s.singularize}")
      else
        expect(resource).to respond_to(:"#{k}=")
      end
    end
  end

  it "should contain the embeddable's methods" do
    resource = Resource.build
    expect(resource).to respond_to(:updated?)
    expect {
      resource.last_updated_on = DateTime.new(year = 1971)
    }.to change { resource.updated? } .from(false).to(true)
  end
end
