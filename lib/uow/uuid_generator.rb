# -*- encoding : utf-8 -*-
require 'securerandom'

module Dilithium
  module UnitOfWork
    class UUIDGenerator
      def self.generate
        SecureRandom.uuid.delete('-')
      end
    end
  end
end
