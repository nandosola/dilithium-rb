class User < BaseEntity
  CHILDREN = [:groups]
end

class Group < BaseEntity
  PARENT = [:users]  # Pluralized names in array of parents
end