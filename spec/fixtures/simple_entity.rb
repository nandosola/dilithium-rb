require 'lib/sequel-uow'

module Repository
  module Sequel
    module UserCustomFinders
      def fetch_by_email email
        result_list = DB[:users].where(email:email).all
        result_list.map {|user_h| User.new(user_h) }
      end
      def fetch_by_name name
        result_list = DB[:users].where(name:name).all
        result_list.map {|user_h| User.new(user_h) }
      end
    end
  end
end

class User < BaseEntity
  extend Repository::Sequel::UserCustomFinders
end


$database.create_table :users do
  primary_key :id
  String :name
  String :email
end
