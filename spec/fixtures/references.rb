# -*- encoding : utf-8 -*-
module Repository
  module Sequel
    module ShipmentCustomFinders
      def fetch_by_name name
        result_list = DB[:shipments].where(name:name).where(active: true).all
        result_list.map {|shipment_h| create_object(shipment_h) }
      end
    end

    module LocationCustomFinders
      def fetch_by_name name
        result_list = DB[:locations].where(name:name).where(active: true).all
        result_list.map {|location_h| create_object(location_h) }
      end
    end
  end
end


class Shipment < BaseEntity
  extend Repository::Sequel::ShipmentCustomFinders

  attribute :name, String
  children :containers
end

class Container < BaseEntity
  parent :shipment
  attribute :kind, String
  children :packages
end

class Package < BaseEntity
  parent :container
  attribute :contents, String
end

class Location < BaseEntity
  extend Repository::Sequel::LocationCustomFinders

  attribute :name, String
end

class Shipyard < BaseEntity
  attribute :name, String
  reference :containers, Container, :multi => true
  reference :location, Location
end
