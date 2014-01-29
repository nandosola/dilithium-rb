require_relative 'spec_base'
require_relative 'fixtures/references'

describe 'An entity with references' do
  before(:all) do
    Mapper::Sequel.create_tables(Shipment, Container, Package, Location, Shipyard)

    a_shipment = Shipment.new({
                                :name => 'A shipment',
                                :containers => [
                                  {
                                    :kind => 'Large',
                                    :packages => [
                                      {
                                        :contents => 'Widgets'
                                      },
                                      {
                                        :contents => 'Doohickeys'
                                      }
                                    ]
                                  },{
                                    :kind => 'Small',
                                    :packages => [
                                      {
                                        :contents => 'Thingamabobs'
                                      },
                                      {
                                        :contents => 'Stuff'
                                      }
                                    ]
                                  }
                                ]
                              })

    a_location = Location.new({:name => 'tumbolia'})

    transaction = UnitOfWork::Transaction.new(Mapper::Sequel)
    transaction.register_new(a_shipment)
    transaction.register_new(a_location)
    transaction.commit

  end

  it 'should have the correct attribute descriptors' do
    Shipyard.attribute_descriptors[:containers].class.should eq(BasicAttributes::ImmutableMultiReference)
    Shipyard.attribute_descriptors[:location].class.should eq(BasicAttributes::ImmutableReference)
  end

  it 'should have the correct methods' do
    a_shipment = Shipment.fetch_by_id(1)
    a_location = Location.fetch_by_id(1)

    a_shipyard = Shipyard.new({
                                :name => 'The shipyard',
                                :location => { :id => a_location.id },
                                :containers => [
                                  { :id => a_shipment.containers[0].id },
                                  { :id => a_shipment.containers[1].id }
                                ]
                              })

    a_shipyard.respond_to?(:location).should be_true
    a_shipyard.respond_to?(:containers).should be_true
    a_shipyard.respond_to?(:location=).should be_true
    a_shipyard.respond_to?(:'containers<<').should be_true
  end

  it 'should create the correct tables' do
    shipyard_schema = $database.schema(:shipyards)
    shipyard_schema[0][0].should eq(:id)
    shipyard_schema[1][0].should eq(:active)
    shipyard_schema[3][0].should eq(:name)
    shipyard_schema[4][0].should eq(:location_id)

    container_schema = $database.schema(:shipyards_containers)
    container_schema[0][0].should eq(:id)
    container_schema[1][0].should eq(:shipyard_id)
    container_schema[2][0].should eq(:container_id)
  end

  it 'should save to and load from the database' do
    a_shipment = Shipment.fetch_by_id(1)
    a_location = Location.fetch_by_id(1)


    a_shipyard = Shipyard.new({
                                :name => 'The shipyard',
                                :location => a_location,
                                :containers => [
                                  a_shipment.containers[0],
                                  a_shipment.containers[1]
                                ]
                              })

    transaction = UnitOfWork::Transaction.new(Mapper::Sequel)
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

  it 'should deserialize correctly from a Hash' do
    a_shipment = Shipment.fetch_by_id(1)
    a_location = Location.fetch_by_id(1)
    shipyard_h = {
      :name => 'The shipyard',
      :location => { :id => a_location.id },
      :containers => [
        { :id => a_shipment.containers[0].id },
        { :id => a_shipment.containers[1].id }
      ]
    }

    a_shipyard = Shipyard.new(shipyard_h)
    location = a_shipyard.location
    location.class.should eq(Association::ImmutableEntityReference)
    #TODO Resolve automatically when calling resolved_entity (and rename resolve to resolve!)
    location.resolve
    location.resolved_entity.class.should eq(Location::Immutable)
    location.resolved_entity.name.should eq('tumbolia')

    containers = a_shipyard.containers
    containers.class.should eq(Array)

    containers[0].class.should eq(Association::ImmutableEntityReference)
    containers[0].resolve
    containers[0].resolved_entity.class.should eq(Container::Immutable)
    containers[0].resolved_entity.kind.should eq('Large')

    containers[1].class.should eq(Association::ImmutableEntityReference)
    containers[1].resolve
    containers[1].resolved_entity.class.should eq(Container::Immutable)
    containers[1].resolved_entity.kind.should eq('Small')
    #TODO Add test for modifying the array (add/delete/update)
  end

  it 'should serialize correctly to a Hash' do
    a_shipment = Shipment.fetch_by_id(1)
    a_location = Location.fetch_by_id(1)
    shipyard_h = {
      :name => 'The shipyard',
      :location => { :id => a_location.id },
      :containers => [
        { :id => a_shipment.containers[0].id },
        { :id => a_shipment.containers[1].id }
      ]
    }

    a_shipyard = Shipyard.new(shipyard_h.clone)

    serialized = EntitySerializer.to_nested_hash(a_shipyard)

    serialized[:name].should eq('The shipyard')
    serialized[:location].should eq(Association::ImmutableEntityReference.new(a_location.id, Location))

    serialized[:containers].each_with_index do |c, i|
      c.should eq(Association::ImmutableEntityReference.new(a_shipment.containers[i].id, Container))
    end
  end
end