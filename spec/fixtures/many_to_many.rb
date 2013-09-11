# Create ad-hoc finder for fetching users by group
# See: http://www.udidahan.com/2009/01/24/ddd-many-to-many-object-relational-mapping/

class Employee < BaseEntity
  #many :groups
  attribute :name, String, mandatory:true
end

class Department < BaseEntity
  #many :users, dependent:true - 'dependent' means that Groups can't exist without Users
  many :employees
  attribute :name, String, mandatory:true
end