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

    module User
      include Base

      def fetch_by_email email
        self[email:email]
      end
      def fetch_by_name name
        self[name:name]
      end
    end

  end
end