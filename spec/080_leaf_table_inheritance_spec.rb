# -*- encoding : utf-8 -*-
require 'fixtures/leaf_table_inheritance'

describe 'A single-inheritance hierarchy of BaseEntities with Leaf Table Inheritance' do
  before(:all) do
    SchemaUtils::Sequel.create_tables(VehicleL, RegisteredVehicleL)
  end

  it 'should create a table per subclass with the correct columns' do
    $database.table_exists?(:vehicle_ls).should be_true
    $database.table_exists?(:registered_vehicle_ls).should be_true

    schema = $database.schema(:vehicle_ls).inject({}) { |memo, s| memo[s[0]] = s[1][:db_type]; memo }
    expect(schema).to eq(
                        :id => 'integer',
                        :active => 'boolean',
                        :_version_id => 'integer',
                        :name => 'varchar(255)'
                      )

    schema = $database.schema(:registered_vehicle_ls).inject({}) { |memo, s| memo[s[0]] = s[1][:db_type]; memo }
    expect(schema).to eq(
                        :id => 'integer',
                        :active => 'boolean',
                        :_version_id => 'integer',
                        :name => 'varchar(255)',
                        :owner => 'varchar(255)'
                      )
  end

  it 'should load data from the database' do
    vehicles = $database[:vehicle_ls]
    registered_vehicles = $database[:registered_vehicle_ls]
    versions = $database[:_versions]

    vehicle_version = versions.insert(:_version => 0, :_version_created_at => DateTime.now)
    registered_version = versions.insert(:_version => 0, :_version_created_at => DateTime.now)
    vehicles.insert(:active => true, :name => 'Heart of Gold', :_version_id=>vehicle_version)
    registered_vehicles.insert(:active => true,
                               :name => 'TARDIS',
                               :owner => 'The Doctor',
                               :_version_id => registered_version)

    hog = VehicleL.fetch_by_id(1)
    tardis = RegisteredVehicleL.fetch_by_id(1)

    hog.name.should eq('Heart of Gold')
    hog.respond_to?(:owner).should be_false

    tardis.name.should eq('TARDIS')
    tardis.owner.should eq('The Doctor')
  end

  pending 'Implement loading from DB with polymorphism in LTI'
  it 'should load data from the database with polymorphism' do
  end

  it 'should save data to the database' do
    bistromath = RegisteredVehicleL.build do |v|
      v.active = true
      v.name = 'Bistromath'
      v.owner = 'Slartibartfast'
    end
    transaction = UnitOfWork::Transaction.new(EntityMapper::Sequel)
    transaction.register_new(bistromath)
    transaction.commit

    result = $database[:registered_vehicle_ls].where(name: 'Bistromath').first
    result[:name].should eq('Bistromath')
  end

  it 'should manage the parent and child references correctly' do
    fleet = FleetL.build do |f|
      f.name = 'Test fleet'
      f.make_ground_vehicle_l(CarL) do |v|
        v.seats = 4
      end
      f.make_ground_vehicle_l(DeliveryVanL) do |v|
        v.capacity = 1000
      end
    end

    car = fleet.ground_vehicle_ls[0]
    car.should be_a(CarL)
    car.fleet_l.should eq(fleet)
    car.seats.should eq(4)

    van = fleet.ground_vehicle_ls[1]
    van.should be_a(DeliveryVanL)
    van.fleet_l.should eq(fleet)
    van.capacity.should eq(1000)
  end

  it 'should serialize correctly into Hashes' do
    fleet = FleetL.build do |f|
      f.name = 'Test fleet'
      f.make_ground_vehicle_l(CarL) do |v|
        v.seats = 4
      end
      f.make_ground_vehicle_l(DeliveryVanL) do |v|
        v.capacity = 1000
      end
    end

    fleet_h = EntitySerializer.to_nested_hash(fleet)
    fleet_h.should eq({:id => nil,
                       :active => true,
                       :_version=>{:id=>nil, :_version=>0,
                                   :_version_created_at=>fleet._version._version_created_at,
                                   :_locked_by=>nil, :_locked_at=>nil},
                       :ground_vehicle_ls => [
                         {:id=>nil, :active=>true,
                          :_version=>{:id=>nil, :_version=>0,
                                      :_version_created_at=>fleet._version._version_created_at,
                                      :_locked_by=>nil, :_locked_at=>nil},
                          :name=>nil, :wheels=>nil, :seats=>4, :_type=>"car_l"},
                         {:id=>nil, :active=>true,
                          :_version=>{:id=>nil, :_version=>0,
                                      :_version_created_at=>fleet._version._version_created_at,
                                      :_locked_by=>nil, :_locked_at=>nil},
                          :name=>nil, :wheels=>nil, :capacity=>1000, :_type=>"delivery_van_l"}],
                       :name => "Test fleet"
                      })
  end

  after :all do
    [:registered_vehicles, :vehicles, :_versions].each do |t|
      $database.drop_table t
      $database << "DELETE FROM SQLITE_SEQUENCE WHERE NAME = '#{t}'"
    end
  end
end
