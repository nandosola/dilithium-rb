# -*- encoding : utf-8 -*-
require 'fixtures/class_table_inheritance'

describe 'A single-inheritance hierarchy of BaseEntities with Class Table Inheritance' do
  before(:all) do
    DatabaseUtils.create_tables(VehicleC, RegisteredVehicleC)
  end

  it 'should create a table per subclass with the correct columns' do
    $database.table_exists?(:vehicle_cs).should be_true
    $database.table_exists?(:registered_vehicle_cs).should be_true

    schema = $database.schema(:vehicle_cs).inject({}) { |memo, s| memo[s[0]] = s[1][:db_type]; memo }
    expect(schema).to eq(
                        :id => 'integer',
                        :active => 'boolean',
                        :_type => 'varchar(255)',
                        :_version_id => 'integer',
                        :name => 'varchar(255)'
                      )

    schema = $database.schema(:registered_vehicle_cs).inject({}) { |memo, s| memo[s[0]] = s[1][:db_type]; memo }
    expect(schema).to eq(
                        :id => 'integer',
                        :owner => 'varchar(255)'
                      )
  end

  it 'should load data from the database' do
    vehicles = $database[:vehicle_cs]
    registered_vehicles = $database[:registered_vehicle_cs]
    versions = $database[:_versions]

    vehicle_version = versions.insert(:_version => 0, :_version_created_at => DateTime.now)
    registered_version = versions.insert(:_version => 0, :_version_created_at => DateTime.now)

    v_id = vehicles.insert(:active => true, :name => 'Heart of Gold', :_version_id => vehicle_version)
    reg_id = vehicles.insert(:active => true, :name => 'TARDIS', :_version_id => registered_version)
    registered_vehicles.insert(:id => reg_id, :owner => 'The Doctor')

    hog = VehicleC.fetch_by_id(v_id)
    tardis = RegisteredVehicleC.fetch_by_id(reg_id)

    expect(hog.class).to eq(VehicleC)
    expect(hog.name).to eq('Heart of Gold')
    expect(hog.respond_to?(:owner)).to be_false

    expect(tardis.class).to eq(RegisteredVehicleC)
    expect(tardis.name).to eq('TARDIS')
    expect(tardis.owner).to eq('The Doctor')

    expect(VehicleC.fetch_by_id(reg_id)).to eq(tardis)
  end

  it 'should save data to the database' do
    bistromath = RegisteredVehicleC.new({:active => true, :name => 'Bistromath', :owner => 'Slartibartfast'})
    transaction = UnitOfWork::Transaction.new(Mapper::Sequel)
    transaction.register_new(bistromath)
    transaction.commit

    v_result = $database[:vehicle_cs].where(name: 'Bistromath').first
    expect(v_result[:name]).to eq('Bistromath')

    r_result = $database[:registered_vehicle_cs].where(name: 'Bistromath').first
    expect(r_result[:id].to eq(v_result[:id]))
    expect(r_result[:owner]).to eq('Slartibartfast')
  end

  it 'should manage the parent and child references correctly' do
    fleet = FleetC.new(:name => 'Test fleet')
    #TODO This should change, the parent should have a factory for its children
    car = CarC.new({:seats => 4}, fleet)
    van = DeliveryVanC.new({:capacity => 1000}, fleet)
    fleet.add_ground_vehicle_c car
    fleet.add_ground_vehicle_c van

    expect(car.fleet_c).to eq(fleet)
    expect(van.fleet_c).to eq(fleet)

    expect(fleet.ground_vehicle_cs).to include(car)
    expect(fleet.ground_vehicle_cs).to include(van)
  end

  it 'should serialize correctly into Hashes' do
    fleet = FleetC.new(:name => 'Test fleet')
    #TODO This should change, the parent should have a factory for its children
    car = CarC.new({:seats => 4}, fleet)
    van = DeliveryVanC.new({:capacity => 1000}, fleet)
    fleet.add_ground_vehicle_c car
    fleet.add_ground_vehicle_c van

    fleet_h = EntitySerializer.to_nested_hash(fleet)
    expect(fleet_h).to eq({:id => nil,
                       :active => true,
                       :_version=>{:id=>nil, :_version=>0,
                                   :_version_created_at=>fleet._version._version_created_at,
                                   :_locked_by=>nil, :_locked_at=>nil},
                       :ground_vehicle_cs => [
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

  it 'should deserialize correctly from a Hash without polymorphism' do
    hash = {
      :name => 'HHGTTG',
      :company_car => { :id => 1 },
      :company_van => { :id => 2 }
    }

    company = SmallCompanyC.new(hash)
    expect(company.name).to eq('HHGTTG')

    expect(company.company_car.class).to eq(Association::ImmutableEntityReference)
    company.company_car.resolve
    company.company_car.resolved_entity.class.should eq(RegisteredVehicleC::Immutable)
    company.company_car.resolved_entity.name.should eq('TARDIS')
    company.company_car.resolved_entity.owner.should eq('The Doctor')

    expect(company.company_van.class).to eq(Association::ImmutableEntityReference)
    company.company_van.resolve
    expect(company.company_van.resolved_entity.class).to eq(RegisteredVehicleC::Immutable)
    expect(company.company_van.resolved_entity.name).to eq('Bistromath')
    expect(company.company_van.resolved_entity.owner).to eq('Slartibartfast')
  end

  pending 'Implement deserialization from polymorphism in CTI'
  it 'should deserialize correctly into a Hash with polymorphism' do

  end

  after :all do
    %i(registered_vehicles vehicles _versions).each do |t|
      $database.drop_table t
      $database << "DELETE FROM SQLITE_SEQUENCE WHERE NAME = '#{t}'"
    end
  end
end
