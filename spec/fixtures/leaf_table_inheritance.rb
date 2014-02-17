# -*- encoding : utf-8 -*-
class Vehicle < BaseEntity
  attribute :name, String
end

class RegisteredVehicle < Vehicle
  attribute :owner, String
end

class Fleet < BaseEntity
  children :ground_vehicles
  attribute :name, String
end

class GroundVehicle < Vehicle
  parent :fleet
  attribute :wheels, Integer
end

class Car < GroundVehicle
  attribute :seats, Integer
end

class DeliveryVan < GroundVehicle
  attribute :capacity, Integer
end

class SmallCompany < BaseEntity
  attribute :name, String
  reference :company_car, RegisteredVehicle
  reference :company_van, RegisteredVehicle
end
