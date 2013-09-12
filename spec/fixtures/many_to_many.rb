# Create ad-hoc finder for fetching users by group
# See: http://www.udidahan.com/2009/01/24/ddd-many-to-many-object-relational-mapping/


class Building < BaseEntity
  #many :departments
  attribute :name, String, mandatory:true
end
class Employee < BaseEntity
  #many :departments
  attribute :name, String, mandatory:true
end

class Department < BaseEntity
  # TODO evaluate: "many :users, dependent:true" - 'dependent' means that Department can't exist without Employee
  many :employees, :buildings
  attribute :name, String, mandatory:true
end