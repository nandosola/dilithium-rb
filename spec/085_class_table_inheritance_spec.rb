# -*- encoding : utf-8 -*-
require 'fixtures/class_table_inheritance'

describe 'A single-inheritance hierarchy of BaseEntities with Class Table Inheritance' do
  before(:all) do
    SchemaUtils::Sequel.create_tables(PersonC,
                                      VehicleC,
                                      RegisteredVehicleC,
                                      FleetC,
                                      GroundVehicleC,
                                      CarC,
                                      DeliveryVanC,
                                      AssignedOwnerC,
                                      SmallCompanyC)
  end

  it 'should create a table per subclass with the correct columns' do
    $database.table_exists?(:vehicle_cs).should be_true
    $database.table_exists?(:registered_vehicle_cs).should be_true
    $database.table_exists?(:registered_vehicle_cs_previous_owners).should be_true

    schema = SchemaUtils::Sequel.get_schema(:vehicle_cs)
    expect(schema).to eq(
                        id: { type: 'integer', primary_key: true},
                        active: { type: 'boolean', primary_key: false},
                        _type: { type: 'varchar(255)', primary_key: false},
                        _version_id: { type: 'integer', primary_key: false},
                        name: { type: 'varchar(255)', primary_key: false}
                      )

    schema = SchemaUtils::Sequel.get_schema(:registered_vehicle_cs)
    expect(schema).to eq(
                        id: { type: 'integer', primary_key: true},
                        owner: { type: 'varchar(255)', primary_key: false}
                      )

    schema = SchemaUtils::Sequel.get_schema(:registered_vehicle_cs_previous_owners)
    expect(schema).to eq(
                        id: { type: 'integer', primary_key: true},
                        registered_vehicle_c_id: { type: 'integer', primary_key: false},
                        person_c_id: { type: 'integer', primary_key: false}
                      )
  end

  it 'should load data from the database' do
    vehicles = $database[:vehicle_cs]
    registered_vehicles = $database[:registered_vehicle_cs]
    versions = $database[:_versions]

    vehicle_version = versions.insert(:_version => 0, :_version_created_at => DateTime.now)
    registered_version = versions.insert(:_version => 0, :_version_created_at => DateTime.now)

    v_id = vehicles.insert(:active => true, :name => 'Heart of Gold',
                           :_type => 'vehicle_cs',
                           :_version_id => vehicle_version)
    reg_id = vehicles.insert(:active => true,
                             :name => 'TARDIS',
                             :_type => 'registered_vehicle_cs',
                             :_version_id => registered_version)
    registered_vehicles.insert(:id => reg_id, :owner => 'The Doctor')

    ['The Doctor', 'Gallifreyan TARDIS Inc.'].each do |name|
      version_id = versions.insert(:_version => 0, :_version_created_at => DateTime.now)
      person_id = $database[:person_cs].insert(:active => true, :name => name, :_version_id => version_id)
      $database[:registered_vehicle_cs_previous_owners].insert(:registered_vehicle_c_id => reg_id,
                                                               :person_c_id => person_id)

    end

    hog = VehicleC.fetch_by_id(v_id)
    tardis = RegisteredVehicleC.fetch_by_id(reg_id)

    expect(hog.class).to eq(VehicleC)
    expect(hog.name).to eq('Heart of Gold')
    expect(hog.respond_to?(:owner)).to be_false

    expect(tardis.class).to eq(RegisteredVehicleC)
    expect(tardis.name).to eq('TARDIS')
    expect(tardis.owner).to eq('The Doctor')
    expect(tardis.previous_owners.length).to eq(2)
    expect(tardis.previous_owners[0].resolve.name).to eq('The Doctor')
    expect(tardis.previous_owners[1].resolve.name).to eq('Gallifreyan TARDIS Inc.')

    reg_fetched = VehicleC.fetch_by_id(reg_id)
    expect(reg_fetched.id).to eq(tardis.id)
    expect(reg_fetched.name).to eq(tardis.name)
    expect(reg_fetched.owner).to eq(tardis.owner)
  end

  it 'should save data to the database' do
    zaphod = PersonC.build { |p| p.name = 'Zaphod Beeblebrox' }
    ford = PersonC.build { |p| p.name = 'Ford Prefect' }

    bistromath = RegisteredVehicleC.build do |v|
      v.active = true
      v.name = 'Bistromath'
      v.owner = 'Slartibartfast'
    end
    
    bistromath.add_previous_owner(zaphod)
    bistromath.add_previous_owner(ford)

    transaction = UnitOfWork::Transaction.new(EntityMapper::Sequel)
    transaction.register_new(zaphod)
    transaction.register_new(bistromath)
    transaction.commit

    v_result = $database[:vehicle_cs].where(id: bistromath.id).first
    expect(v_result[:_type]).to eq('registered_vehicle_cs')
    expect(v_result[:name]).to eq(bistromath.name)

    r_result = $database[:registered_vehicle_cs].where(id: v_result[:id]).first
    expect(r_result[:owner]).to eq(bistromath.owner)

    i_result = $database[:registered_vehicle_cs_previous_owners].where(registered_vehicle_c_id: bistromath.id)
    expect(i_result.count).to eq(2)
    owners = i_result.all.map { |h| h[:id] }
    expect(owners).to include(zaphod.id)
    expect(owners).to include(ford.id)
  end

  it 'should update data in the database' do
    id = $database[:vehicle_cs].where(name:'Bistromath').first[:id]
    bistromath = VehicleC.fetch_by_id(id)
    transaction = UnitOfWork::Transaction.new(EntityMapper::Sequel)
    transaction.register_dirty(bistromath)
    bistromath.name = 'Krikkit One'
    bistromath.owner = 'Hactar'
    transaction.commit

    v_result = $database[:vehicle_cs].where(id: bistromath.id).first
    expect(v_result[:_type]).to eq('registered_vehicle_cs')
    expect(v_result[:name]).to eq(bistromath.name)

    r_result = $database[:registered_vehicle_cs].where(id: bistromath.id).first
    expect(r_result[:owner]).to eq(bistromath.owner)
  end

  it 'should store references and children correctly' do
    v_1 = VehicleC.fetch_by_id(1)
    v_2 = VehicleC.fetch_by_id(2)

    company = SmallCompanyC.build do |c|
      c.name = 'HHGTTG'
      c.company_car = v_1
      c.company_van = v_2
      c.add_company_car(v_1)
      c.add_company_car(v_2)      
    end

    transaction = UnitOfWork::Transaction.new(EntityMapper::Sequel)
    transaction.register_new(company)
    transaction.commit

    company_h = $database[:small_company_cs].where(:id => company.id).first
    expect(company_h[:company_car_id]).to eq(v_1.id)
    expect(company_h[:company_van_id]).to eq(v_2.id)

    intermediate_table = $database[:small_company_cs_company_cars].where(:small_company_c_id => company.id)
    expect(intermediate_table.count).to eq(2)

    count = intermediate_table.where(:vehicle_c_id => v_1.id).count
    expect(count).to eq(1)

    count = intermediate_table.where(:vehicle_c_id => v_2.id).count
    expect(count).to eq(1)
  end

  it 'should mark a deleted entity as inactive' do
    id = $database[:vehicle_cs].where(name:'Krikkit One').first[:id]
    bistromath = VehicleC.fetch_by_id(id)
    transaction = UnitOfWork::Transaction.new(EntityMapper::Sequel)
    transaction.register_deleted(bistromath)
    transaction.commit

    v_result = $database[:vehicle_cs].where(id: bistromath.id).first
    expect(v_result[:active]).to be_false
  end

  it 'should manage the parent and child references correctly' do
    fleet = FleetC.build do |f|
      f.name = 'Test fleet'
      f.make_ground_vehicle_c(CarC) do |v|
        v.wheels = 4
        v.seats = 4
      end
      
      f.make_ground_vehicle_c(DeliveryVanC) do |v|
        v.wheels = 4
        v.capacity = 1000
      end
      
      f.make_ground_vehicle_c do |v|
        v.wheels = 2
        v.make_assigned_owner_c do |o|
          o.name = 'Foo'
        end
      end
    end

    expect(fleet.ground_vehicle_cs.size).to eq(3)

    car = fleet.ground_vehicle_cs[0]
    expect(car).to be_a(CarC)
    expect(car.fleet_c).to eq(fleet)
    expect(car.wheels).to eq(4)
    expect(car.seats).to eq(4)

    van = fleet.ground_vehicle_cs[1]
    expect(van).to be_a(DeliveryVanC)
    expect(van.fleet_c).to eq(fleet)
    expect(van.capacity).to eq(1000)

    motorcycle = fleet.ground_vehicle_cs[2]
    expect(motorcycle).to be_a (GroundVehicleC)
    expect(motorcycle.fleet_c).to eq(fleet)
    expect(motorcycle.wheels).to eq(2)
    expect(motorcycle.assigned_owner_cs.size).to eq(1)

    owner = motorcycle.assigned_owner_cs.first
    expect(owner).to be_a(AssignedOwnerC)
    expect(owner.ground_vehicle_c).to eq(motorcycle)

    transaction = UnitOfWork::Transaction.new(EntityMapper::Sequel)
    transaction.register_new(fleet)
    transaction.commit
  end

  it 'should serialize correctly into Hashes' do
    fleet = FleetC.build do |f|
      f.name = 'Test fleet'
      f.make_ground_vehicle_c(CarC) do |v|
        v.wheels = 4
        v.seats = 4
      end

      f.make_ground_vehicle_c(DeliveryVanC) do |v|
        v.wheels = 4
        v.capacity = 1000
      end
    end

    fleet_h = EntitySerializer.to_nested_hash(fleet)
    version_h = {
      :id=>nil,
      :_version=>0,
      :_version_created_at => fleet._version._version_created_at,
      :_locked_by => nil,
      :_locked_at=>nil
    }

    expect(fleet_h).to eq({
                            :id => nil, :active => true, :_version => version_h,
                            :ground_vehicle_cs => [
                              {
                                :id => nil, :active => true, :_version => version_h,
                                :assigned_owner_cs => [],
                                :name => nil, :wheels => 4, :seats => 4,
                                :_type => 'car_c'
                              },
                              {
                                :id => nil, :active => true, :_version => version_h,
                                :assigned_owner_cs => [],
                                :name => nil, :wheels => 4, :capacity => 1000,
                                :_type => 'delivery_van_c'

                              }
                            ],
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
