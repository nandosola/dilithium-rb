require 'pp'
require 'sequel'
# connect to an in-memory database
DB = Sequel.sqlite

# create an items table
DB.create_table :users do
  primary_key :id
  String :name
  String :email
end

$:<< File.join(File.dirname(__FILE__), '..')
require_relative 'spec_helpers'
include SpecHelpers

Dir[ File.join(File.dirname(__FILE__),'*_spec.rb') ].sort.each do |path|
  require path
end
