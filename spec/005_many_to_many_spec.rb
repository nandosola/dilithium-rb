require_relative '../spec/fixtures/many_to_many'

describe 'A Many to many relationship' do

  before(:all) do
    Mapper::Sequel.create_tables(Employee, Department)
    insert_test_employees_and_depts
  end

  it 'must have an intermediate table in the database' do
    $database.table_exists?(:departments_employees).should be_true
    schema = $database.schema(:departments_employees)
    schema[0][0].should eq(:id)
    schema[1][0].should eq(:department_id)
    schema[2][0].should eq(:employee_id)
  end

  after(:all) do
    delete_test_employees_and_depts
  end
end

