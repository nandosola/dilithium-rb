# Create ad-hoc finder for fetching users by group
# See: http://www.udidahan.com/2009/01/24/ddd-many-to-many-object-relational-mapping/


class Building < BaseEntity
  #many :employees
  attribute :name, String, mandatory:true
end
class Employee < BaseEntity
  # TODO evaluate: "many :employee, dependent:true" - 'dependent' means that Employees can't exist without Department
  multi_reference :departments, :buildings
  attribute :name, String, mandatory:true
end

class Department < BaseEntity
  #many :employees
  attribute :name, String, mandatory:true
end
