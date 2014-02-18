# -*- encoding : utf-8 -*-
require 'fixtures/leaf_table_inheritance'

describe 'A single-inheritance hierarchy of BaseEntities' do
  before(:all) do
    DatabaseUtils.create_tables(Vehicle, RegisteredVehicle)
  end

  it 'should create a table per subclass with the correct columns' do
    $database.table_exists?(:vehicles).should be_true
    $database.table_exists?(:registered_vehicles).should be_true

    schema = $database.schema(:vehicles)
    schema[0][0].should eq(:id)
    schema[0][1][:db_type].should eq('integer')
    schema[1][0].should eq(:active)
    schema[1][1][:db_type].should eq('boolean')
    schema[3][0].should eq(:name)
    schema[3][1][:db_type].should eq('varchar(255)')

    schema = $database.schema(:registered_vehicles)
    schema[0][0].should eq(:id)
    schema[0][1][:db_type].should eq('integer')
    schema[1][0].should eq(:active)
    schema[1][1][:db_type].should eq('boolean')
    schema[3][0].should eq(:name)
    schema[3][1][:db_type].should eq('varchar(255)')
    schema[4][0].should eq(:owner)
    schema[4][1][:db_type].should eq('varchar(255)')
  end

  it 'should load data from the database' do
    vehicles = $database[:vehicles]
    registered_vehicles = $database[:registered_vehicles]
    versions = $database[:_versions]

    vehicle_version = versions.insert(:_version => 0, :_version_created_at => DateTime.now)
    registered_version = versions.insert(:_version => 0, :_version_created_at => DateTime.now)
    vehicles.insert(:active => true, :name => 'Heart of Gold', :_version_id=>vehicle_version)
    registered_vehicles.insert(:active => true,
                               :name => 'TARDIS',
                               :owner => 'The Doctor',
                               :_version_id => registered_version)

    hog = Vehicle.fetch_by_id(1)
    tardis = RegisteredVehicle.fetch_by_id(1)

    hog.name.should eq('Heart of Gold')
    hog.respond_to?(:owner).should be_false

    tardis.name.should eq('TARDIS')
    tardis.owner.should eq('The Doctor')
  end

  pending 'Implement loading from DB with polymorphism in LTI'
  it 'should load data from the database with polymorphism' do
  end

  it 'should save data to the database' do
    bistromath = RegisteredVehicle.new({:active => true, :name => 'Bistromath', :owner => 'Slartibartfast'})
    transaction = UnitOfWork::Transaction.new(Mapper::Sequel)
    transaction.register_new(bistromath)
    transaction.commit

    result = $database[:registered_vehicles].where(name: 'Bistromath').first
    result[:name].should eq('Bistromath')
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

  it 'should serialize correctly into Hashes' do
    fleet = Fleet.new(:name => 'Test fleet')
    #TODO This should change, the parent should have a factory for its children
    car = Car.new({:seats => 4}, fleet)
    van = DeliveryVan.new({:capacity => 1000}, fleet)
    fleet.ground_vehicles<< car
    fleet.ground_vehicles<< van

    fleet_h = EntitySerializer.to_nested_hash(fleet)
    fleet_h.should eq({:id => nil,
                       :active => true,
                       :_version=>{:id=>nil, :_version=>0,
                                   :_version_created_at=>fleet._version._version_created_at,
                                   :_locked_by=>nil, :_locked_at=>nil},
                       :ground_vehicles => [
                         {:id=>nil, :active=>true,
                          :_version=>{:id=>nil, :_version=>0,
                                      :_version_created_at=>fleet._version._version_created_at,
                                      :_locked_by=>nil, :_locked_at=>nil},
                          :name=>nil, :wheels=>nil, :seats=>4},
                         {:id=>nil, :active=>true,
                          :_version=>{:id=>nil, :_version=>0,
                                      :_version_created_at=>fleet._version._version_created_at,
                                      :_locked_by=>nil, :_locked_at=>nil},
                          :name=>nil, :wheels=>nil, :capacity=>1000}],
                       :name => "Test fleet"
                      })
  end

  it 'should deserialize correctly into a Hash without polymorphism' do
    hash = {
      :name => 'HHGTTG',
      :company_car => { :id => 1 },
      :company_van => { :id => 2 }
    }

    company = SmallCompany.new(hash)
    company.name.should eq('HHGTTG')

    company.company_car.class.should eq(Association::ImmutableEntityReference)
    company.company_car.resolve
    company.company_car.resolved_entity.class.should eq(RegisteredVehicle::Immutable)
    company.company_car.resolved_entity.name.should eq('TARDIS')
    company.company_car.resolved_entity.owner.should eq('The Doctor')

    company.company_van.class.should eq(Association::ImmutableEntityReference)
    company.company_van.resolve
    company.company_van.resolved_entity.class.should eq(RegisteredVehicle::Immutable)
    company.company_van.resolved_entity.name.should eq('Bistromath')
    company.company_van.resolved_entity.owner.should eq('Slartibartfast')
  end

  pending 'Implement deserialization with polymorphism in LTI'
  it 'should deserialize correctly into a Hash with polymorphism' do

  end

  after :all do
    %i(registered_vehicles vehicles _versions).each do |t|
      $database.drop_table t
      $database << "DELETE FROM SQLITE_SEQUENCE WHERE NAME = '#{t}'"
    end
  end
end
