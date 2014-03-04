# -*- encoding : utf-8 -*-
require 'pp'
require 'sequel'
require 'logger'

require 'dilithium'

include Dilithium

$database = Sequel.sqlite
PersistenceService::Sequel.db = $database

PersistenceService.configure do |config|
  config.inheritance_mappers(
    :'Dilithium::BaseEntity' => :leaf,
    :'PersistenceConfigTest::Base' => :class,
    :FleetC => :class,
    :VehicleC => :class
  )
end

$database.logger = Logger.new($stdout)

$:<< File.join(File.dirname(__FILE__), '..')
require_relative 'spec_fixtures'
include SpecFixtures
