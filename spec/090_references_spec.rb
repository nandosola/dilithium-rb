# -*- encoding : utf-8 -*-
require_relative 'spec_base'
require_relative 'fixtures/references'

describe 'An entity with references' do

  let (:a_shipment) {
    Shipment.build do |s|
      s.name = 'A referenced shipment'

      s.make_container do |c|
        c.kind = 'Large'
        c.make_package { |p| p.contents = 'Widgets'}
        c.make_package { |p| p.contents = 'Doohickeys'}
      end

      s.make_container do |c|
        c.kind = 'Small'
        c.make_package { |p| p.contents = 'Thingamabobs'}
        c.make_package { |p| p.contents = 'Stuff'}
      end
    end
  }

  let (:a_location) {
    Location.build { |l| l.name = 'tumbolia' }
  }

  let (:a_shipyard) { Shipyard.build do |s|
    s.name = 'The shipyard'
    s.location = a_location
    a_shipment.containers.each { |c| s.add_container(c) }
  end
  }

  before(:all) do
    transaction = UnitOfWork::Transaction.new(EntityMapper::Sequel)
    transaction.register_new(a_shipment)
    transaction.register_new(a_location)
    transaction.commit
  end

  it 'should have the correct attribute descriptors' do
    Shipyard.attribute_descriptors[:containers].class.should eq(BasicAttributes::ImmutableMultiReference)
    Shipyard.attribute_descriptors[:location].class.should eq(BasicAttributes::ImmutableReference)
  end

  it 'should have the correct methods' do
    a_shipyard.respond_to?(:location).should be_true
    a_shipyard.respond_to?(:containers).should be_true
    a_shipyard.respond_to?(:location=).should be_true
    a_shipyard.respond_to?(:'add_container').should be_true
  end

  it 'should create the correct tables' do
    shipyard_schema = $database.schema(:shipyards)
    shipyard_schema[0][0].should eq(:id)
    shipyard_schema[1][0].should eq(:active)
    shipyard_schema[2][0].should eq(:name)
    shipyard_schema[3][0].should eq(:location_id)

    container_schema = $database.schema(:shipyards_containers)
    container_schema[0][0].should eq(:id)
    container_schema[1][0].should eq(:shipyard_id)
    container_schema[2][0].should eq(:container_id)
  end

  it 'should save to and load from the database' do
    transaction = UnitOfWork::Transaction.new(EntityMapper::Sequel)
    transaction.register_new(a_shipyard)
    transaction.commit

    shipyard_row = $database[:shipyards].where(:id => 1).first
    shipyard_row[:name].should eq(a_shipyard.name)
    shipyard_row[:location_id].should eq(a_shipyard.location.id)

    shipyard_containers = $database[:shipyards_containers].where(:shipyard_id => 1)
    matched_containers = shipyard_containers.zip(a_shipyard.containers)
    matched_containers.length.should eq(a_shipyard.containers.length)
    matched_containers.each { |match| match[0][:container_id].should eq(match[1].id) }

    fetched_shipyard = Shipyard.fetch_by_id(1)
    fetched_shipyard.name.should eq(a_shipyard.name)

    fetched_shipyard.location.id.should eq(a_shipyard.location.id)

    matched_containers = fetched_shipyard.containers.zip(a_shipyard.containers)
    matched_containers.length.should eq(a_shipyard.containers.length)
    matched_containers.each { |match| match[0].id.should eq(match[1].id) }
  end

  it 'should serialize correctly to a Hash' do
    serialized = EntitySerializer.to_nested_hash(a_shipyard)

    serialized[:name].should eq('The shipyard')
    serialized[:location].should eq(Association::ImmutableEntityReference.new(a_location.id, Location))

    serialized[:containers].each_with_index do |c, i|
      c.should eq(Association::ImmutableEntityReference.new(a_shipment.containers[i].id, Container))
    end
  end
end
