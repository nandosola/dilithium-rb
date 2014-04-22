# -*- encoding : utf-8 -*-
require 'securerandom'
require 'openwfe/util/kotoba'

module Dilithium
  module UnitOfWork
    class UUIDGenerator
      HEX_BASE = 16

      def self.generate
        SecureRandom.uuid.delete('-')
      end

      def self.kotoba(obj)
        obj.object_id.to_s(HEX_BASE) + '-' + Kotoba.from_i(Time.now.utc.strftime("%Y%d%m%H%M%S%L").to_i)
      end

    end
  end
end
