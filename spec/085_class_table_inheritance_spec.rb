# -*- encoding : utf-8 -*-
require 'fixtures/class_table_inheritance'

describe 'A single-inheritance hierarchy of BaseEntities with Class Table Inheritance' do
  before(:all) do
    SchemaUtils::Sequel.create_tables(VehicleC,
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

    v_id = vehicles.insert(:active => true, :name => 'Heart of Gold',
                           :_type => 'vehicle_cs',
                           :_version_id => vehicle_version)
    reg_id = vehicles.insert(:active => true,
                             :name => 'TARDIS',
                             :_type => 'registered_vehicle_cs',
                             :_version_id => registered_version)
    registered_vehicles.insert(:id => reg_id, :owner => 'The Doctor')

    hog = VehicleC.fetch_by_id(v_id)
    tardis = RegisteredVehicleC.fetch_by_id(reg_id)

    expect(hog.class).to eq(VehicleC)
    expect(hog.name).to eq('Heart of Gold')
    expect(hog.respond_to?(:owner)).to be_false

    expect(tardis.class).to eq(RegisteredVehicleC)
    expect(tardis.name).to eq('TARDIS')
    expect(tardis.owner).to eq('The Doctor')

    reg_fetched = VehicleC.fetch_by_id(reg_id)
    expect(reg_fetched.id).to eq(tardis.id)
    expect(reg_fetched.name).to eq(tardis.name)
    expect(reg_fetched.owner).to eq(tardis.owner)
  end

  it 'should save data to the database' do
    bistromath = RegisteredVehicleC.new({:active => true, :name => 'Bistromath', :owner => 'Slartibartfast'})
    transaction = UnitOfWork::Transaction.new(EntityMapper::Sequel)
    transaction.register_new(bistromath)
    transaction.commit

    v_result = $database[:vehicle_cs].where(id: bistromath.id).first
    expect(v_result[:_type]).to eq('registered_vehicle_cs')
    expect(v_result[:name]).to eq(bistromath.name)

    r_result = $database[:registered_vehicle_cs].where(id: v_result[:id]).first
    expect(r_result[:owner]).to eq(bistromath.owner)
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

    company = SmallCompanyC.new
    company.name = 'HHGTTG'
    company.company_car = v_1
    company.company_van = v_2
    company.add_company_car(v_1)
    company.add_company_car(v_2)

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
    fleet = FleetC.new(:name => 'Test fleet')

    #TODO This should change, the parent should have a factory for its children
    car = CarC.new({:wheels => 4, :seats => 4}, fleet)
    van = DeliveryVanC.new({:wheels => 4, :capacity => 1000}, fleet)
    motorcycle = GroundVehicleC.new({:wheels => 2}, fleet)

    owner = AssignedOwnerC.new({:name => 'Foo'}, motorcycle)
    motorcycle.add_assigned_owner_c(owner)

    fleet.add_ground_vehicle_c car
    fleet.add_ground_vehicle_c van
    fleet.add_ground_vehicle_c motorcycle

    expect(motorcycle.assigned_owner_cs).to include(owner)
    expect(owner.ground_vehicle_c).to eq(motorcycle)

    expect(car.fleet_c).to eq(fleet)
    expect(van.fleet_c).to eq(fleet)
    expect(motorcycle.fleet_c).to eq(fleet)

    expect(fleet.ground_vehicle_cs).to include(car)
    expect(fleet.ground_vehicle_cs).to include(van)
    expect(fleet.ground_vehicle_cs).to include(motorcycle)

    transaction = UnitOfWork::Transaction.new(EntityMapper::Sequel)
    transaction.register_new(fleet)
    transaction.commit

  end

  it 'should serialize correctly into Hashes' do
    fleet = FleetC.new(:name => 'Test fleet')
    #TODO This should change, the parent should have a factory for its children
    car = CarC.new({:seats => 4}, fleet)
    van = DeliveryVanC.new({:capacity => 1000}, fleet)

    fleet.add_ground_vehicle_c car
    fleet.add_ground_vehicle_c van

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
                                :name => nil, :wheels => nil, :seats => 4
                              },
                              {
                                :id => nil, :active => true, :_version => version_h,
                                :assigned_owner_cs => [],
                                :name => nil, :wheels => nil, :capacity => 1000
                              }
                            ],
                            :name => "Test fleet"
                          })
  end


  {
    :id => nil, :active => true,
    :_version => {:id => nil, :_version => 0, :_version_created_at => "DateTime", :_locked_by => nil, :_locked_at => nil},
    :ground_vehicle_cs => [
      {
        :id => nil, :active => true,
        :_version => {:id => nil, :_version => 0, :_version_created_at => "DateTime", :_locked_by => nil, :_locked_at => nil},
        :assigned_owner_c => [
          {
            :id => nil, :active => true, :name => "Eccentrica Gallumbits",
            :_version => {:id => nil, :_version => 0, :_version_created_at => "DateTime", :_locked_by => nil, :_locked_at => nil}
          }
        ],
        :name => nil, :wheels => nil, :seats => 4
      }, {
        :id => nil, :active => true,
        :_version => {:id => nil, :_version => 0, :_version_created_at => "DateTime", :_locked_by => nil, :_locked_at => nil},
        :assigned_owner_c => [], :name => nil, :wheels => nil, :capacity => 1000
      }
    ], :name => "Test fleet"
  }


  {
    :id => nil, :active => true,
    :ground_vehicle_cs => [
      {
        :id => nil, :active => true, :name => nil, :assigned_owner_cs => [], :wheels => nil, :seats => 4,
        :_version => {:id => nil, :_version => 0, :_version_created_at => "DateTime", :_locked_by => nil, :_locked_at => nil}
      }, {
        :id => nil, :active => true, :name => nil, :assigned_owner_cs => [], :wheels => nil, :capacity => 1000,
        :_version => {:id => nil, :_version => 0, :_version_created_at => "DateTime", :_locked_by => nil, :_locked_at => nil}
      }
    ],
    :name => "Test fleet",
    :_version => {:id => nil, :_version => 0, :_version_created_at => "DateTime", :_locked_by => nil, :_locked_at => nil}
  }

  it 'should deserialize correctly from a Hash' do
    v_1 = VehicleC.fetch_by_id(1)
    v_2 = VehicleC.fetch_by_id(2)

    hash = {
      :name => 'HHGTTG',
      :company_car => { :id => v_1.id },
      :company_van => { :id => v_2.id }
    }

    company = SmallCompanyC.new(hash)
    expect(company.name).to eq('HHGTTG')

    expect(company.company_car.class).to eq(Association::ImmutableEntityReference)
    expect(company.company_car.resolved_entity.class).to eq(v_1.class.const_get(:Immutable))
    expect(company.company_car.resolved_entity.name).to eq(v_1.name)

    expect(company.company_van.class).to eq(Association::ImmutableEntityReference)
    expect(company.company_van.resolved_entity.class).to eq(v_2.class.const_get(:Immutable))
    expect(company.company_van.resolved_entity.name).to eq(v_2.name)
  end

  after :all do
    %i(registered_vehicles vehicles _versions).each do |t|
      $database.drop_table t
      $database << "DELETE FROM SQLITE_SEQUENCE WHERE NAME = '#{t}'"
    end
  end
end
