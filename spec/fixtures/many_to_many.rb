# Create ad-hoc finder for fetching users by group
# See: http://www.udidahan.com/2009/01/24/ddd-many-to-many-object-relational-mapping/


class Building < BaseEntity
  #many :employees
  attribute :name, String, mandatory:true
end

class Department < BaseEntity
  #many :employees
  attribute :name, String, mandatory:true
end

class Employee < BaseEntity
  # TODO evaluate: "many :employee, dependent:true" - 'dependent' means that Employees can't exist without Department
  # TODO: is multi_reference and reference :multi => true the same case? If not the same case, multi_reference should be attribute :multi => true
  multi_reference :departments
  multi_reference :buildings
  multi_reference :managed_departments, Department
  attribute :name, String, mandatory:true
end
