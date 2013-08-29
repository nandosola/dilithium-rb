String.inflections do |inflect|
  inflect.irregular 'company', 'companies'
  inflect.irregular 'local_office', 'local_offices'
  inflect.irregular 'address', 'addresses'
end

class Company < BaseEntity
  CHILDREN = [:local_offices]
end

class LocalOffice < BaseEntity
  CHILDREN = [:addresses]
  PARENT = :company
end

class Address < BaseEntity
  PARENT = :local_office
end

$database.create_table(:companies) do
  primary_key :id
  String :name
  String :url
  String :email
  String :vat_number
  Boolean :active, :default => true
end

$database.create_table(:local_offices) do
  primary_key :id
  String :description
  foreign_key :company_id, :companies
  Boolean :active, :default => true
end

$database.create_table(:addresses) do
  primary_key :id
  String :description
  foreign_key :local_office_id, :local_offices
  String :address
  String :city
  String :state
  String :country
  String :zip
  String :phone
  String :fax
  String :email
  TrueClass :office, :default => true
  TrueClass :warehouse, :default => false
  Boolean :active, :default => true
end
