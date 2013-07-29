require 'securerandom'

class UUIDGenerator
  def self.generate
    SecureRandom.uuid.delete('-')
  end
end
