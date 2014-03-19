# -*- encoding : utf-8 -*-
require_relative 'spec_base'
require 'lib/model/base_value'

describe 'BaseValue class' do

  let(:planet) {
    Class.new(BaseValue) do
      attribute :iso2, String
      attribute :iso3, String
      attribute :name, String
      attribute :type, String
    end
  }

  let(:alien) {
    Class.new(BaseValue) do
      attribute :race, String
      attribute :subrace, String
      attribute :hostility_level, String
    end
  }

  let(:planet_h) {
    {iso2:'NU', iso3:'NRU', name:'Nibiru', type:'Y'}
  }

  let(:another_planet_h) {
    {iso2:'GY', iso3:'GFY', name:'Gallifrey', type:'M'}
  }

  describe '::identified_by' do

    it 'accepts any type of previously defined attributes' do

      expect { planet.identified_by(:bogus) }.to raise_error(ArgumentError)

      planet.identified_by(:iso2)
      expect(planet.instance_variable_get(:'@identifiers')).to eq([:iso2])
    end

    it 'can only be called once' do
      planet.identified_by(:iso2)
      expect { planet.identified_by(:iso3) }.to raise_error(DomainObjectExceptions::ConfigurationError)
    end

    it 'accepts multiple attributes' do
      alien.identified_by(:race, :subrace)
      expect(alien.instance_variable_get(:'@identifiers')).to eq([:race, :subrace])
    end
  end

  describe '#==' do
    it 'Compares objects by their values' do
      a_planet = planet.new(planet_h.dup)
      the_same_planet = planet.new(planet_h)
      another_planet = planet.new(another_planet_h)

      expect(a_planet).to eq(the_same_planet)
      expect(a_planet).to_not eq(another_planet)
    end
  end

  #TODO We are currently including setters for attributes in the BaseValue (to be called from load_self_attributes).
  # These setters should not be there since BaseValue should be immutable.

  #TODO The attributes method is not tested, it should be tested in the BaseMethods::Attributes tests once we refactor
  # them out of their current places in BaseEntity/EmbeddableValue
end

describe 'BaseValue persistence' do
  before(:all) do
    class Planet < BaseValue
      attribute :iso2, String
      attribute :iso3, String
      attribute :name, String
      attribute :type, String
      identified_by :iso2
    end

    class Alien < BaseValue
      attribute :race, String
      attribute :subrace, String
      attribute :hostility_level, Integer
      identified_by :race, :subrace
    end
  end

  describe '#create_tables' do
    before(:all) do
      DatabaseUtils.create_tables(Planet, Alien)
    end

    after(:all) do
      $database.drop_table :planets
      $database.drop_table :aliens
    end

    it 'Creates the tables' do
      $database.table_exists?(:planets).should be_true
      $database.table_exists?(:aliens).should be_true
    end

    it 'Creates the tables with the proper columns when identified_by has a single field' do
      expect(DatabaseUtils.get_schema(:planets)).to eq({
                                                         iso2: {type: 'varchar(255)', primary_key: true},
                                                         iso3: {type: 'varchar(255)', primary_key: false},
                                                         name: {type: 'varchar(255)', primary_key: false},
                                                         type: {type: 'varchar(255)', primary_key: false}
                                                       })

    end

    it 'Creates the tables with the proper columns when identified_by has multiple fields' do
      expect(DatabaseUtils.get_schema(:aliens)).to eq({
                                                        race: {type: 'varchar(255)', primary_key: true},
                                                        subrace: {type: 'varchar(255)', primary_key: true},
                                                        hostility_level: {type: 'integer', primary_key: false}
                                                      })
    end
  end

  describe 'BaseValue mapper - Leaf-Table Inheritance' do
    describe 'With a single identified_by key' do
      before(:each) do
        DatabaseUtils.create_tables(Planet)
        planet_mapper.insert(a_planet)
      end

      after(:each) do
        $database.drop_table :planets
      end

      let(:planet_h) {
        {iso2:'NU', iso3:'NRU', name:'Nibiru', type:'Y'}
      }

      let(:a_planet) {
        Planet.new(planet_h.dup)
      }

      let(:planet_mapper) {
        Mapper::Sequel.mapper_for(Planet)
      }

      describe '#insert' do
        it 'Inserts a new BaseValue with a identified_by' do
          result_h = $database[:planets].where(iso2: planet_h[:iso2]).first
          expect(result_h).to eq(planet_h)
        end

        it 'Doesn\'t allow inserting a BaseValue with the same identifier value, ' do
          a_planet.iso3 = 'NBU'
          a_planet.type = 'y'
          expect { planet_mapper.insert(a_planet) }.to raise_error(Sequel::UniqueConstraintViolation)
        end
      end

      describe '#update' do
        it 'Updates the fields in a BaseValue' do

        end
      end

      describe '#delete' do

      end
    end
  end

  describe 'BaseValue repository' do

  end
end
