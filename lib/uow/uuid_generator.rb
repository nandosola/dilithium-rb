require 'securerandom'

module UnitOfWork
  class UUIDGenerator
    def self.generate
      SecureRandom.uuid.delete('-')
    end
  end
end
