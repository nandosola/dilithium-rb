# -*- encoding : utf-8 -*-
require 'pp'
require 'sequel'
require 'logger'

require 'dilithium'
include Dilithium

$database = Sequel.sqlite
PersistenceService::Sequel.db = $database

#$database.logger = Logger.new($stdout)

$:<< File.join(File.dirname(__FILE__), '..')
require_relative 'spec_fixtures'
include SpecFixtures
