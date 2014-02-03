String.inflections do |inflect|
  inflect.irregular 'company', 'companies'
  inflect.irregular 'local_office', 'local_offices'
  inflect.irregular 'address', 'addresses'
end

module Repository
  module Sequel
    module CompanyCustomFinders
      def fetch_by_name name
        result_list = DB[:companies].where(name: name).where(active: true).all
        result_list.map {|company_h| create_object(company_h) }
      end
    end

    module ContractorCustomFinders
      def fetch_by_name name
        result_list = DB[:contractors].where(name: name).where(active: true).all
        result_list.map {|contractor_h| create_object(contractor_h) }
      end
    end
  end
end

class Company < BaseEntity
  extend Repository::Sequel::CompanyCustomFinders

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
  attribute :office, TrueClass, :default => true
  attribute :warehouse, TrueClass, :default => false
end

class Contractor < BaseEntity
  extend Repository::Sequel::ContractorCustomFinders

  reference :local_office, LocalOffice
  attribute :name, String
  attribute :email, String
end
