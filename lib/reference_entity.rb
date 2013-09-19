class ReferenceEntity
  attr_reader :id, :type
  def initialize(id, referenced_class)
    @id = id
    @type = referenced_class
  end
end