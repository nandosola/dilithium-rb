require 'pp'
require 'sequel'
require 'logger'
require_relative '../lib/sequel-uow'

$database = Sequel.sqlite
PersistenceService::Sequel.db = $database

#$database.logger = Logger.new($stdout)

$:<< File.join(File.dirname(__FILE__), '..')
require_relative 'spec_fixtures'
include SpecFixtures

Dir[ File.join(File.dirname(__FILE__),'*_spec.rb') ].sort.each do |path|
  require path
end
