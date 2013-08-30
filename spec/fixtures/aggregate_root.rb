String.inflections do |inflect|
  inflect.irregular 'company', 'companies'
  inflect.irregular 'local_office', 'local_offices'
  inflect.irregular 'address', 'addresses'
end

class Company < BaseEntity
  children :local_offices

  attribute :name, String
  attribute :url, String
  attribute :email, String
  attribute :vat_number, String
end

class LocalOffice < BaseEntity
  children  :addresses
  parent :company

  attribute :description, String
end

class Address < BaseEntity
  parent :local_office

  attribute :description, String
  attribute :address, String
  attribute :city, String
  attribute :state, String
  attribute :country, String
  attribute :zip, String
  attribute :phone, String
  attribute :fax, String
  attribute :email, String
  #attribute :office, Boolean, :default => true
  #attribute :warehouse, TrueClass, :default => false
end