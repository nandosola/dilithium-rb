require_relative '../spec/fixtures/many_to_many'

describe 'A BasicEntity with a many to many relationship' do

  before(:all) do
    Mapper::Sequel.create_tables(Employee, Department, Building)
    insert_test_employees_depts_and_buildings

    module Mapper
      class Sequel
        # TESTING PURPOSES ONLY: eliminates dependencies with Transaction
        def self.check_uow_transaction(base_entity)
        end
      end
    end

  end

  it 'must have an intermediate table in the database' do
    $database.table_exists?(:employees_departments).should be_true
    $database.table_exists?(:employees_buildings).should be_true

    schema = $database.schema(:employees_departments)
    schema[0][0].should eq(:id)
    schema[1][0].should eq(:employee_id)
    schema[2][0].should eq(:department_id)

    schema = $database.schema(:employees_buildings)
    schema[0][0].should eq(:id)
    schema[1][0].should eq(:employee_id)
    schema[2][0].should eq(:building_id)
  end

  it 'must have the correct class attributes' do
    attr = Employee.attributes[2]
    attr.is_a?(BasicAttributes::ManyReference).should be_true
    attr.name.should eq(:departments)

    attr = Employee.attributes[3]
    attr.is_a?(BasicAttributes::ManyReference).should be_true
    attr.name.should eq(:buildings)
  end

  it 'has its instance attribute accessors' do
    employee = Employee.new({name:'Beppe'})
    dept1 = Department.new({name:'Evil'})
    dept2 = Department.new({name:'Hell'})
    bld1 = Building.new({name:'Marquee'})
    bld2 = Building.new({name:'Fawlty Towers'})
    employee.departments<<(dept1)
    employee.departments<<(dept2)
    employee.buildings<<(bld1)
    employee.buildings<<(bld2)
    employee.departments.should eq([dept1, dept2])
    employee.buildings.should eq([bld1, bld2])
  end

  it 'has a way to traverse the relationship' do
    employee = Employee.new({name:'Beppe'})
    dept1 = Department.new({name:'Evil'})
    dept2 = Department.new({name:'Hell'})
    bld1 = Building.new({name:'Marquee'})
    bld2 = Building.new({name:'Fawlty Towers'})
    employee.departments<<(dept1)
    employee.departments<<(dept2)
    employee.buildings<<(bld1)
    employee.buildings<<(bld2)

    many_a = []
    employee.each_multi_reference do |many|
      many_a << many
    end
    many_a.should eq([dept1, dept2, bld1, bld2])
  end

  it 'is correctly serialized' do
    emp = Employee.new({name:'Oscar'})
    dept = Department.new({name:'Evil'})
    emp.departments<<dept
    EntitySerializer.to_hash(emp)[:departments].should eq([dept])
    EntitySerializer.to_nested_hash(emp)[:departments].should eq([EntitySerializer.to_hash(dept)])
    EntitySerializer.to_row(emp)[:departments].should be_nil
  end

  it 'is persisted in two tables' do
    emp = Employee.new({name:'Beppe'})
    dept = Department.fetch_by_id(1)
    emp.departments<<dept

    Mapper::Sequel.insert(emp)
    $database[:employees_departments].first.should include(:employee_id => emp.id)
    $database[:employees_departments].first.should include(:department_id => dept.id)
  end

  it 'is persisted even when the dependent side doesn\'t exist anymore' do
    pending 'Corner case: soft deletes should be handled by the application'
    emp = Employee.new({name:'Avi'})
    dept = Department.fetch_by_id(1)
    emp.departments<<dept

    Mapper::Sequel.delete(dept)

    Mapper::Sequel.insert(emp)
    #foo = $database[:employees_departments].all
  end

  it 'is correctly recovered from the database' do
    emp = Employee.new({name:'Katrina'})
    dept = Department.fetch_by_id(1)
    dept2 = Department.fetch_by_id(2)
    bld = Building.fetch_by_id(1)
    emp.departments<<dept
    emp.departments<<dept2
    emp.buildings<<bld

    Mapper::Sequel.insert(emp)

    katrina = Employee.fetch_by_id(emp.id)
    katrina.name.should eq(emp.name)
    katrina.departments.size.should eq(2)
    katrina.departments[0].id.should eq(1)
    katrina.departments[1].id.should eq(2)
    katrina.buildings.size.should eq(1)
    katrina.buildings[0].id.should eq(1)


  end

  after(:all) do
    delete_test_employees_depts_and_buildings
  end
end