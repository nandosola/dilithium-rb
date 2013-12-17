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
