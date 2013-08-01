module Repository
  module Sequel

    module Base
      def fetch_by_id id
        self[id:id]
      end
      def fetch_all
        self.all
      end
    end
  end
end