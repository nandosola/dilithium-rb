# -*- encoding : utf-8 -*-

module Dilithium

  class MarshalledState
    attr_reader :obj_id, :state
    def initialize(obj)
      @obj_id = obj.object_id.to_s.to_sym
      @state = Marshal.dump(obj)
    end
    def unmarshal
      Marshal.load(@state)
    end
  end

  module Savepoint
    def save
      MarshalledState.new(self)
    end
    def restore(marshalled_state)
      replace_state marshalled_state.unmarshal
    end
    private
    def replace_state(other)
      other.instance_variables.each do |var|
        instance_variable_set(var, other.instance_variable_get(var))
      end
    end
  end
end