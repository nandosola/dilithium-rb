# -*- encoding : utf-8 -*-

require_relative 'spec_base'
require_relative 'fixtures/configuration'

describe 'PersistenceService' do
  describe '#configure' do
    it 'returns the configuration for BaseEntity' do
      expect(PersistenceService.inheritance_mapper_for(BaseEntity)).to eq(:leaf)
    end

    it 'returns the configuration for a specifically-configured class' do
      expect(PersistenceService.inheritance_mapper_for(::PersistenceConfigTest::Base)).to eq(:class)
    end

    it 'returns the configuration for a non-configured subclass' do
      expect(PersistenceService.inheritance_mapper_for(::PersistenceConfigTest::Subclass)).to eq(:class)
    end

    it 'doesn\'t allow changing the configuration it has been set' do
      expect {
        PersistenceService.configure do |config|
          config.inheritance_mappers(
            :'PersistenceConfigTest::Base' => :leaf
          )
        end
      }.to raise_error(PersistenceService::ConfigurationError)
    end

    it 'doesn\'t allow getting the configuration for a non-BaseEntity' do
      expect {PersistenceService.inheritance_mapper_for(Object)}.to raise_error(PersistenceService::ConfigurationError)
    end

    it 'doesn\'t allow setting an invalid Mapper type' do
      expect {
        PersistenceService.configure do |config|
          config.inheritance_mappers(
            :'PersistenceConfigTest::Base' => :foo
          )
        end
      }.to raise_error(PersistenceService::ConfigurationError)
    end
  end
end