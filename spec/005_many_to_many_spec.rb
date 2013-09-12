require_relative '../spec/fixtures/many_to_many'

describe 'A BasicEntity with a many to many relationship' do

  before(:all) do
    Mapper::Sequel.create_tables(Employee, Department, Building)
    insert_test_employees_depts_and_buildings
  end

  it 'must have an intermediate table in the database' do
    $database.table_exists?(:departments_employees).should be_true
    $database.table_exists?(:departments_buildings).should be_true

    schema = $database.schema(:departments_employees)
    schema[0][0].should eq(:id)
    schema[1][0].should eq(:department_id)
    schema[2][0].should eq(:employee_id)

    schema = $database.schema(:departments_buildings)
    schema[0][0].should eq(:id)
    schema[1][0].should eq(:department_id)
    schema[2][0].should eq(:building_id)
  end

  it 'must have the correct class attributes' do
    attr = Department.attributes[2]
    attr.is_a?(BasicAttributes::ManyReference).should be_true
    attr.name.should eq(:employees)

    attr = Department.attributes[3]
    attr.is_a?(BasicAttributes::ManyReference).should be_true
    attr.name.should eq(:buildings)
  end

  it 'has its instance attribute accessors' do
    department = Department.new({name:'Evil'})
    emp1 = Employee.new({name:'Beppe'})
    emp2 = Employee.new({name:'Oscar'})
    bld1 = Building.new({name:'Marquee'})
    bld2 = Building.new({name:'Fawlty Towers'})
    department.employees<<(emp1)
    department.employees<<(emp2)
    department.buildings<<(bld1)
    department.buildings<<(bld2)
    department.employees.should eq([emp1, emp2])
    department.buildings.should eq([bld1, bld2])
  end

  it 'has a way to traverse the relationship' do
    department = Department.new({name:'Evil'})
    emp1 = Employee.new({name:'Beppe'})
    emp2 = Employee.new({name:'Oscar'})
    bld1 = Building.new({name:'Marquee'})
    bld2 = Building.new({name:'Fawlty Towers'})
    department.employees<<(emp1)
    department.employees<<(emp2)
    department.buildings<<(bld1)
    department.buildings<<(bld2)

    emp_a = []
    department.each_many do |emp|
      emp_a << emp
    end
    emp_a.should eq([emp1, emp2, bld1, bld2])
  end

  it 'is correctly serialized' do
    dept = Department.new({name:'Evil'})
    emp = Employee.new({name:'Oscar'})
    dept.employees<<emp
    EntitySerializer.to_hash(dept)[:employees].should eq([emp])
    EntitySerializer.to_nested_hash(dept)[:employees].should eq([EntitySerializer.to_hash(emp)])
    EntitySerializer.to_row(dept)[:employees].should be_nil
  end

  after(:all) do
    delete_test_employees_depts_and_buildings
  end
end

