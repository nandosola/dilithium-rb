module Repository
  class NotFound < Exception
    attr_accessor :id, :type
    def initialize(id, type)
      super("#{type} with ID #{id} not found")
      @id = id
      @type = type
    end
  end
end