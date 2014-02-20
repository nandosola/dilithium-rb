# -*- encoding : utf-8 -*-
class VehicleL < BaseEntity
  attribute :name, String
end

class RegisteredVehicleL < VehicleL
  attribute :owner, String
end

class FleetL < BaseEntity
  children :ground_vehicle_ls
  attribute :name, String
end

class GroundVehicleL < VehicleL
  parent :fleet_l
  attribute :wheels, Integer
end

class CarL < GroundVehicleL
  attribute :seats, Integer
end

class DeliveryVanL < GroundVehicleL
  attribute :capacity, Integer
end

class SmallCompanyL < BaseEntity
  attribute :name, String
  reference :company_car, RegisteredVehicleL
  reference :company_van, RegisteredVehicleL
end
