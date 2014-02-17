# -*- encoding : utf-8 -*-
module UnitOfWork
  module States
    module Default
      STATE_NEW = :new
      STATE_DIRTY = :dirty
      STATE_CLEAN = :clean
      STATE_DELETED = :removed
      ALL_STATES = [STATE_NEW, STATE_DIRTY, STATE_CLEAN, STATE_DELETED]
    end
  end
end
