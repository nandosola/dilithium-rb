module Sequel
  module BaseRepository

    def fetch_by_id id
      self[id:id]
    end
    def fetch_all
      self.all
    end
  end

  module UserRepository
    include BaseRepository

    def fetch_by_email email
      self[email:email]
    end
    def fetch_by_name name
      self[name:name]
    end
  end
end

# TODO cache all domain objects assigned to a UoW

