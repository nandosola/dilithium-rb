# -*- encoding : utf-8 -*-
class VehicleC < BaseEntity
  attribute :name, String
end

class RegisteredVehicleC < VehicleC
  attribute :owner, String
end

class FleetC < BaseEntity
  children :ground_vehicle_cs
  attribute :name, String
end

class GroundVehicleC < VehicleC
  parent :fleet_c
  attribute :wheels, Integer
end

class CarC < GroundVehicleC
  attribute :seats, Integer
end

class DeliveryVanC < GroundVehicleC
  attribute :capacity, Integer
end

class SmallCompanyC < BaseEntity
  attribute :name, String
  reference :company_car, RegisteredVehicleC
  reference :company_van, RegisteredVehicleC
end
