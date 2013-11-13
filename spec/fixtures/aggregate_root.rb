String.inflections do |inflect|
  inflect.irregular 'company', 'companies'
  inflect.irregular 'local_office', 'local_offices'
  inflect.irregular 'address', 'addresses'
end

module Repository
  module Sequel
    module LocalOfficeCustomFinders
      def fetch_by_description description
        result_list = DB[:local_offices].where(description: description).where(active: true).all
        result_list.map {|office_h| create_object(office_h) }
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
  children :local_offices

  attribute :name, String
  attribute :url, String
  attribute :email, String
  attribute :vat_number, String
end

class LocalOffice < BaseEntity
  extend Repository::Sequel::LocalOfficeCustomFinders

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

  attribute :local_office, LocalOffice
  attribute :name, String
  attribute :email, String
end
