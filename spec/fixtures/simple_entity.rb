module Repository
  module Sequel
    module UserCustomFinders
      def fetch_by_email email
        result_list = DB[:users].where(email:email).where(active: true).all
        result_list.map {|user_h| create_object(user_h) }
      end
      def fetch_by_name name
        result_list = DB[:users].where(name:name).where(active: true).all
        result_list.map {|user_h| create_object(user_h) }
      end
    end
  end
end

class Reference < BaseEntity
  attribute :name, String
end

require 'bcrypt'

class User < BaseEntity
  extend Repository::Sequel::UserCustomFinders

  attribute :name, String, mandatory:true
  attribute :email, String
  attribute :title, String, default:'Esq.'
  attribute :tstamp, DateTime
  attribute :password, BCrypt::Password, default:BCrypt::Password.create('secret')

  reference :reference, Reference
  reference :refers_to, Reference
end