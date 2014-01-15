module AuditInfo
  extend EmbeddableValue

  attribute :created_on, DateTime
  reference :created_by, User
  attribute :last_updated_on, DateTime
  reference :last_updated_by, User
  reference :update_history, User, :multi => true

  def updated?
    self.created_on != self.last_updated_on
  end
end

class Resource < BaseEntity
  include AuditInfo

  attribute :type, String
end
