# -*- encoding : utf-8 -*-
require 'thread'

module Dilithium

  class IntegerSequence < BasicAttributes::WrappedInteger
    @@lock = ::Mutex.new

    def self.get_next(value_object)
      table = SchemaUtils::Sequel.to_table_name(value_object)
      @@lock.synchronize {IntegerSequence.new(DB[table].count + 1)}
    end
  end

  module PhantomIdentifier
    extend EmbeddableValue

    self.singleton_class.send(:alias_method, :__included, :included)
    def self.included(base)
      raise ArgumentError, "PhantomIdentifier can be only embedded in BaseValue" unless base < BaseValue
      __included(base)
    end

    attribute :_phantomid, IntegerSequence

  end

end