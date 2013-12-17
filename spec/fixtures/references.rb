class Shipment < BaseEntity
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
  attribute :name, String
end

class Shipyard < BaseEntity
  attribute :name, String
  reference :containers, Container, :multi => true
  reference :location, Location
end