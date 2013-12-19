require 'fixtures/leaf_table_inheritance'

describe 'A single-inheritance hierarchy of BaseEntities' do
  before(:all) do
    Mapper::Sequel.create_tables(Vehicle, RegisteredVehicle)
  end

  it 'should create a table per subclass with the correct columns' do
    $database.table_exists?(:vehicles).should be_true
    $database.table_exists?(:registered_vehicles).should be_true

    schema = $database.schema(:vehicles)
    schema[0][0].should eq(:id)
    schema[0][1][:db_type].should eq('integer')
    schema[1][0].should eq(:active)
    schema[1][1][:db_type].should eq('boolean')
    schema[2][0].should eq(:name)
    schema[2][1][:db_type].should eq('varchar(255)')

    schema = $database.schema(:registered_vehicles)
    schema[0][0].should eq(:id)
    schema[0][1][:db_type].should eq('integer')
    schema[1][0].should eq(:active)
    schema[1][1][:db_type].should eq('boolean')
    schema[2][0].should eq(:name)
    schema[2][1][:db_type].should eq('varchar(255)')
    schema[3][0].should eq(:owner)
    schema[3][1][:db_type].should eq('varchar(255)')
  end

  it 'should manage each class independently' do
    vehicles = $database[:vehicles]
    registered_vehicles = $database[:registered_vehicles]

    vehicles.insert(:active => true, :name => 'Heart of Gold')
    registered_vehicles.insert(:active => true, :name => 'TARDIS', :owner => 'The Doctor')

    hog = Vehicle.fetch_by_id(1)
    tardis = RegisteredVehicle.fetch_by_id(1)

    hog.name.should eq('Heart of Gold')
    hog.respond_to?(:owner).should be_false

    tardis.name.should eq('TARDIS')
    tardis.owner.should eq('The Doctor')
  end

  it 'should manage the parent and child references correctly' do
    fleet = Fleet.new(:name => 'Test fleet')
    #TODO This should change, the parent should have a factory for its children
    car = Car.new({:seats => 4}, fleet)
    van = DeliveryVan.new({:capacity => 1000}, fleet)
    fleet.ground_vehicles<< car
    fleet.ground_vehicles<< van

    car.fleet.should eq(fleet)
    van.fleet.should eq(fleet)

    fleet.ground_vehicles.should include(car)
    fleet.ground_vehicles.should include(van)
  end

  it 'should serialize/deserialize correctly into Hashes' do
    fleet = Fleet.new(:name => 'Test fleet')
    #TODO This should change, the parent should have a factory for its children
    car = Car.new({:seats => 4}, fleet)
    van = DeliveryVan.new({:capacity => 1000}, fleet)
    fleet.ground_vehicles<< car
    fleet.ground_vehicles<< van

    fleet_h = EntitySerializer.to_nested_hash(fleet)
    fleet_h.should eq({
                        :active => true,
                        :ground_vehicles => [
                          {:id=>nil, :active=>true, :name=>nil, :wheels=>nil, :seats=>4},
                          {:id=>nil, :active=>true, :name=>nil, :wheels=>nil, :capacity=>1000}],
                        :id => nil,
                        :name => "Test fleet"
                    })

    #TODO Deserialize (add type tags - :_subtype and use a Factory?)
  end
end