class Vehicle < BaseEntity
  attribute :name, String
end

class RegisteredVehicle < Vehicle
  attribute :owner, String
end