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

