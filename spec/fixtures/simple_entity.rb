module Repository
  module Sequel
    module UserCustomFinders
      def fetch_by_email email
        result_list = DB[:users].where(email:email).where(active: true).all
        result_list.map {|user_h| User.new(user_h) }
      end
      def fetch_by_name name
        result_list = DB[:users].where(name:name).where(active: true).all
        result_list.map {|user_h| User.new(user_h) }
      end
    end
  end
end

class Reference < BaseEntity
  attribute :name, String
end

class User < BaseEntity
  extend Repository::Sequel::UserCustomFinders

  #has_many :groups
  attribute :name, String, mandatory:true
  attribute :email, String

  attribute :reference, Reference
end

#class Group < BaseEntity
#  attribute :name, String, mandatory:true
#end