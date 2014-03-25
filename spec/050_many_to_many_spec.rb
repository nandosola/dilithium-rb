# -*- encoding : utf-8 -*-
require_relative 'spec_base'

require_relative '../spec/fixtures/many_to_many'

describe 'A BasicEntity with a many to many relationship' do

  before(:all) do
    SchemaUtils::Sequel.create_tables(Employee, Department, Building)
    insert_test_employees_depts_and_buildings

    module EntityMapper
      module Sequel
        # TESTING PURPOSES ONLY: eliminates dependencies with Transaction
        def self.check_uow_transaction(base_entity)
        end
      end
    end

  end

  it 'must have an intermediate table in the database' do
    $database.table_exists?(:employees_departments).should be_true
    $database.table_exists?(:employees_managed_departments).should be_true
    $database.table_exists?(:employees_buildings).should be_true

    schema = $database.schema(:employees_departments)
    schema[0][0].should eq(:id)
    schema[1][0].should eq(:employee_id)
    schema[2][0].should eq(:department_id)

    schema = $database.schema(:employees_managed_departments)
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
    attr.is_a?(BasicAttributes::MultiReference).should be_true
    attr.name.should eq(:departments)
    attr.inner_type.should eq(Department)

    attr = Employee.attributes[3]
    attr.is_a?(BasicAttributes::MultiReference).should be_true
    attr.name.should eq(:buildings)

    attr = Employee.attributes[4]
    attr.is_a?(BasicAttributes::MultiReference).should be_true
    attr.name.should eq(:managed_departments)
    attr.inner_type.should eq(Department)
  end

  it 'has its instance attribute accessors' do
    employee = Employee.new({name:'Beppe'})
    dept1 = Department.new({name:'Evil'})
    dept2 = Department.new({name:'Hell'})
    dept3 = Department.new({name:'Mad Science'})
    dept4 = Department.new({name:'Apocalypse'})

    bld1 = Building.new({name:'Marquee'})
    bld2 = Building.new({name:'Fawlty Towers'})

    employee.add_department(dept1)
    employee.add_department(dept2)
    employee.add_managed_department(dept3)
    employee.add_managed_department(dept4)
    employee.add_building(bld1)
    employee.add_building(bld2)

    employee.departments.should eq([dept1, dept2])
    employee.managed_departments.should eq([dept3, dept4])
    employee.buildings.should eq([bld1, bld2])
  end

  it 'has a way to traverse the relationship' do
    employee = Employee.new({name:'Beppe'})
    dept1 = Department.new({name:'Evil'})
    dept2 = Department.new({name:'Hell'})
    dept3 = Department.new({name:'Mad Science'})
    dept4 = Department.new({name:'Apocalypse'})

    bld1 = Building.new({name:'Marquee'})
    bld2 = Building.new({name:'Fawlty Towers'})

    employee.add_department(dept1)
    employee.add_department(dept2)
    employee.add_managed_department(dept3)
    employee.add_managed_department(dept4)
    employee.add_building(bld1)
    employee.add_building(bld2)

    many_a = []
    employee.each_multi_reference do |many|
      many_a << many
    end

    many_a.should eq([dept1, dept2, bld1, bld2, dept3, dept4])
  end

  it 'is ignored when generating the immutable version of an model' do
    employee = Employee.new({name:'Beppe'})
    dept1 = Department.new({name:'Evil'})
    dept2 = Department.new({name:'Hell'})
    dept3 = Department.new({name:'Mad Science'})
    dept4 = Department.new({name:'Apocalypse'})

    bld1 = Building.new({name:'Marquee'})
    bld2 = Building.new({name:'Fawlty Towers'})

    employee.add_department(dept1)
    employee.add_department(dept2)
    employee.add_managed_department(dept3)
    employee.add_managed_department(dept4)
    employee.add_building(bld1)
    employee.add_building(bld2)

    immutable = employee.immutable

    immutable.respond_to?(:departments).should be_false
    immutable.respond_to?(:managed_departments).should be_false
    immutable.respond_to?(:buildings).should be_false
  end

  it 'is correctly serialized' do
    emp = Employee.new({name:'Oscar'})
    dept = Department.new({name:'Evil'})
    dept2 = Department.new({name:'Mad Science'})

    emp2 = Employee.new({name:'Mayer'})
    ref_dept = Association::LazyEntityReference.new(2, Department)

    emp.add_department dept
    EntitySerializer.to_hash(emp)[:departments].should eq([dept])
    EntitySerializer.to_nested_hash(emp)[:departments].should eq([EntitySerializer.to_nested_hash(dept)])
    SchemaUtils::Sequel.to_row(emp)[:departments].should be_nil

    emp.add_managed_department dept2
    EntitySerializer.to_hash(emp)[:managed_departments].should eq([dept2])
    EntitySerializer.to_nested_hash(emp)[:managed_departments].should eq([EntitySerializer.to_nested_hash(dept2)])
    SchemaUtils::Sequel.to_row(emp)[:managed_departments].should be_nil

    emp2.add_department ref_dept
    EntitySerializer.to_hash(emp2)[:departments].should eq([ref_dept])
    EntitySerializer.to_nested_hash(emp2)[:departments].should eq([EntitySerializer.to_nested_hash(ref_dept)])
    SchemaUtils::Sequel.to_row(emp2)[:departments].should be_nil

    existing_ref_dept = Association::LazyEntityReference.new(1, Department)
    existing_ref_dept.resolve
    EntitySerializer.to_nested_hash(existing_ref_dept.resolved_entity).should eq({id:1,
                                                                                  name:'Accounting',
                                                                                  active:true,
                                                                                  _version:{:id=>4, :_version=>0,
                                                                                            :_version_created_at=>existing_ref_dept._version._version_created_at,
                                                                                       :_locked_by=>nil, :_locked_at=>nil}})
  end

  it 'is persisted in two tables (accessor initialization)' do
    emp = Employee.new({name:'Beppe'})
    dept = Department.fetch_by_id(1)
    dept2 = Department.fetch_by_id(2)
    dept3 = Department.fetch_by_id(3)
    dept4 = Department.fetch_by_id(4)

    emp.add_department dept
    emp.add_department dept2
    emp.add_managed_department dept3
    emp.add_managed_department dept4

    EntityMapper::Sequel.insert(emp)

    found_depts = $database[:employees_departments].all
    found_depts[0].should include(:employee_id => emp.id)
    found_depts[0].should include(:department_id => dept.id)
    found_depts[1].should include(:employee_id => emp.id)
    found_depts[1].should include(:department_id => dept2.id)

    found_managed_depts = $database[:employees_managed_departments].all
    found_managed_depts[0].should include(:employee_id => emp.id)
    found_managed_depts[0].should include(:department_id => dept3.id)
    found_managed_depts[1].should include(:employee_id => emp.id)
    found_managed_depts[1].should include(:department_id => dept4.id)
  end

  it 'is persisted in two tables (full initialization)' do
    dept = Department.fetch_by_id(1)
    dept2 = Department.fetch_by_id(2)
    dept3 = Department.fetch_by_id(3)
    dept4 = Department.fetch_by_id(4)

    emp = Employee.new({name:'Grillo', departments:[dept, dept2], managed_departments:[dept3, dept4]})

    EntityMapper::Sequel.insert(emp)

    found_depts = $database[:employees_departments].where(employee_id:emp.id).all
    found_depts[0].should include(:employee_id => emp.id)
    found_depts[0].should include(:department_id => dept.id)
    found_depts[1].should include(:employee_id => emp.id)
    found_depts[1].should include(:department_id => dept2.id)

    found_managed_depts = $database[:employees_managed_departments].where(employee_id:emp.id).all
    found_managed_depts[0].should include(:employee_id => emp.id)
    found_managed_depts[0].should include(:department_id => dept3.id)
    found_managed_depts[1].should include(:employee_id => emp.id)
    found_managed_depts[1].should include(:department_id => dept4.id)
  end

  it 'can be persisted through ReferenceEntities' do
    dept = Department.fetch_reference_by_id(1)
    dept2 = Department.fetch_reference_by_id(2)
    dept3 = Department.fetch_reference_by_id(3)
    dept4 = Department.fetch_reference_by_id(4)

    # TODO: this should be ReferenceRepository.fetch_by_id(Department, 1)
    # #=> <LazyEntityReference 0xf00b45: @id=1 @type=Department>
    #
    # Likewise: AggregateRepository.fetch_by_id(Department, 1)
    # #=> <Department 0xf00b45: @id=1 ... BaseEntity attrs...>

    emp = Employee.new({name:'Kenneth', departments:[dept, dept2], managed_departments:[dept3, dept4]})

    EntityMapper::Sequel.insert(emp)
    found_depts = $database[:employees_departments].where(employee_id:emp.id).all
    found_depts[0].should include(:employee_id => emp.id)
    found_depts[0].should include(:department_id => dept.id)
    found_depts[1].should include(:employee_id => emp.id)
    found_depts[1].should include(:department_id => dept2.id)

    found_managed_depts = $database[:employees_managed_departments].where(employee_id:emp.id).all
    found_managed_depts[0].should include(:employee_id => emp.id)
    found_managed_depts[0].should include(:department_id => dept3.id)
    found_managed_depts[1].should include(:employee_id => emp.id)
    found_managed_depts[1].should include(:department_id => dept4.id)
  end

  it 'is persisted even when the dependent side doesn\'t exist anymore' do
    pending 'Corner case: soft deletes should be handled by the application'
    emp = Employee.new({name:'Avi'})
    dept = Department.fetch_by_id(1)
    emp.add_departmentdept

    EntityMapper::Sequel.delete(dept)

    EntityMapper::Sequel.insert(emp)
    #foo = $database[:employees_departments].all
  end

  it 'is correctly recovered from the database' do
    emp = Employee.new({name:'Katrina'})
    dept = Department.fetch_by_id(1)
    dept2 = Department.fetch_by_id(2)
    dept3 = Department.fetch_by_id(3)
    dept4 = Department.fetch_by_id(4)

    bld = Building.fetch_by_id(1)

    emp.add_department dept
    emp.add_department dept2
    emp.add_managed_department dept3
    emp.add_managed_department dept4
    emp.add_building bld

    EntityMapper::Sequel.insert(emp)

    katrina = Employee.fetch_by_id(emp.id)
    katrina.name.should eq(emp.name)

    katrina.departments.size.should eq(2)
    katrina.departments[0].id.should eq(1)
    katrina.departments[1].id.should eq(2)
    katrina.managed_departments.size.should eq(2)
    katrina.managed_departments[0].id.should eq(3)
    katrina.managed_departments[1].id.should eq(4)
    katrina.buildings.size.should eq(1)
    katrina.buildings[0].id.should eq(1)

    katrina.departments.first.class.should eq(Association::LazyEntityReference)
    katrina.departments.first.resolve
    katrina.departments.first.resolved_entity.name.should eq('Accounting')
    katrina.departments.first.resolved_entity.id.should eq(1)

    katrina.managed_departments.first.class.should eq(Association::LazyEntityReference)
    katrina.managed_departments.first.resolve
    katrina.managed_departments.first.resolved_entity.name.should eq('Sales')
    katrina.managed_departments.first.resolved_entity.id.should eq(3)
  end

  it 'correctly updates its intermediate table when deleting a reference' do
    kati_id = 7
    katrina = Employee.fetch_by_id(kati_id)
    orig_katrina = Marshal.load(Marshal.dump(katrina))

    dept1 = katrina.departments[1]
    dept2 = katrina.departments[0]

    dept1_id = dept1.id
    dept2_id = dept2.id

    katrina.full_update({id:katrina.id, name:katrina.name, departments:[dept1], managed_departments:[dept2], buildings:[]})
    katrina.departments.size.should eq(1)
    katrina.managed_departments.size.should eq(1)
    katrina.buildings.size.should eq(0)

    EntityMapper::Sequel.update(katrina, orig_katrina)

    found_depts = $database[:employees_departments].where(employee_id:kati_id).all
    found_depts.size.should eq(1)
    found_depts[0].should include({:employee_id=>kati_id, :department_id=>dept1_id})

    found_managed_depts = $database[:employees_managed_departments].where(employee_id:kati_id).all
    found_managed_depts.size.should eq(1)
    found_managed_depts[0].should include({:employee_id=>kati_id, :department_id=>dept2_id})

    $database[:employees_buildings].where(employee_id:kati_id).all.should eq([])
  end

  after(:all) do
    %i(employees_departments employees_buildings employees_managed_departments
       buildings departments employees _versions).each do |t|
      $database.drop_table t
      $database << "DELETE FROM SQLITE_SEQUENCE WHERE NAME = '#{t}'"
    end
  end
end
