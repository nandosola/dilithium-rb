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

  let(:planet_h) { {iso2:'NU', iso3:'NRU', name:'Nibiru', type:'Y'} }

  let(:another_planet_h) { {iso2:'GY', iso3:'GFY', name:'Gallifrey', type:'M'} }

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

  describe 'accessors' do
    it 'Has the proper accessors' do
      a_planet = planet.new(planet_h.dup)

      expect(a_planet).to respond_to(:iso2)
      expect(a_planet).to respond_to(:iso3)
      expect(a_planet).to respond_to(:name)
      expect(a_planet).to respond_to(:type)

      expect(a_planet.iso2).to eq(planet_h[:iso2])
      expect(a_planet.iso3).to eq(planet_h[:iso3])
      expect(a_planet.name).to eq(planet_h[:name])
      expect(a_planet.type).to eq(planet_h[:type])
    end

    it 'Has mutators that throw an exception' do
      #TODO See comments for Issue #49: It should really not have mutators but they are needed to load data initially
      a_planet = planet.new(planet_h.dup)

      expect(a_planet).to respond_to(:iso2=)
      expect(a_planet).to respond_to(:iso3=)
      expect(a_planet).to respond_to(:name=)
      expect(a_planet).to respond_to(:type=)

      expect { a_planet.iso2 = 'GF' }.to raise_error(::Dilithium::DomainObjectExceptions::ImmutableObjectError)
      expect { a_planet.iso3 = 'GFY' }.to raise_error(::Dilithium::DomainObjectExceptions::ImmutableObjectError)
      expect { a_planet.name = 'Gallifrey' }.to raise_error(::Dilithium::DomainObjectExceptions::ImmutableObjectError)
      expect { a_planet.type = 'M' }.to raise_error(::Dilithium::DomainObjectExceptions::ImmutableObjectError)
    end
  end
end

describe 'BaseValue infrastructure' do
  describe 'persistence' do
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
        SchemaUtils::Sequel.create_tables(Planet, Alien)
      end

      after(:all) do
        $database.drop_table :planets
        $database.drop_table :aliens
      end

      it 'Creates the tables' do
        $database.table_exists?(:planets).should be_true
        $database.table_exists?(:aliens).should be_true
      end

      it 'Creates the tables with the proper columns with a single key' do
        expect(SchemaUtils::Sequel.get_schema(:planets)).to eq({
                                                                 iso2: {type: 'varchar(255)', primary_key: true},
                                                                 iso3: {type: 'varchar(255)', primary_key: false},
                                                                 name: {type: 'varchar(255)', primary_key: false},
                                                                 type: {type: 'varchar(255)', primary_key: false},
                                                                 active: {type: 'boolean', primary_key: false}

                                                               })

      end

      it 'Creates the tables with the proper columns with a compound key' do
        expect(SchemaUtils::Sequel.get_schema(:aliens)).to eq({
                                                                race: {type: 'varchar(255)', primary_key: true},
                                                                subrace: {type: 'varchar(255)', primary_key: true},
                                                                hostility_level: {type: 'integer', primary_key: false},
                                                                active: {type: 'boolean', primary_key: false}
                                                              })
      end
    end

    describe 'mapper - Leaf-Table Inheritance' do
      describe 'With a single key' do
        before(:each) do
          SchemaUtils::Sequel.create_tables(Planet)
          planet_mapper.insert(a_planet)
        end

        after(:each) do
          $database.drop_table :planets
        end

        let(:planet_h) { {iso2: 'NU', iso3:'NRU', name:'Nibiru', type:'Y', active:true} }

        let(:a_planet) { Planet.new(planet_h.dup) }

        let(:planet_mapper) { Mapper::Sequel.mapper_for(Planet) }

        describe '#insert' do
          it 'Inserts a new BaseValue' do
            result_h = $database[:planets].where(iso2: planet_h[:iso2]).first
            expect(result_h).to eq(planet_h)
          end

          it 'Doesn\'t allow inserting a BaseValue with the same identifier value, ' do
            another_planet_h = planet_h.merge({iso3: 'NBU', type:'y'})
            another_planet = Planet.new(another_planet_h)
            expect { planet_mapper.insert(another_planet) }.to raise_error(Sequel::UniqueConstraintViolation)
          end
        end

        describe '#update' do
          it 'Updates the fields in a BaseValue' do
            planet_h[:iso3] = 'NBU'
            planet_h[:name] = 'Nibiru 2'
            planet_h[:type] = 'X'

            expect {
              planet_mapper.update(Planet.new(planet_h.dup), a_planet)
            }.to raise_error(Dilithium::PersistenceExceptions::ImmutableObjectError)
          end
        end

        describe '#delete' do
          it 'Deletes a BaseValue from the DB' do
            planet_mapper.delete(a_planet)

            modified_h = $database[:planets].where(iso2: planet_h[:iso2]).first
            expect(modified_h[:active]).to be_false
          end
        end
      end

      describe 'With multiple keys' do
        before(:each) do
          SchemaUtils::Sequel.create_tables(Alien)
          alien_mapper.insert(an_alien)
        end

        after(:each) do
          $database.drop_table :aliens
        end

        let(:alien_h) { {race: 'Dalek', subrace: 'Davros', hostility_level: 100, active:true} }

        let(:an_alien) { Alien.new(alien_h.dup) }

        let(:alien_mapper) { Mapper::Sequel.mapper_for(Alien) }

        describe '#insert' do
          it 'Inserts a new BaseValue' do
            result_h = $database[:aliens].where(race: alien_h[:race], subrace: alien_h[:subrace]).first
            expect(result_h).to eq(alien_h)
          end

          it 'Doesn\'t allow inserting a BaseValue with the same identifier values' do
            another_alien_h = alien_h.merge({hostility_level: 90})
            another_alien = Alien.new(another_alien_h)
            #TODO We should be getting a Sequel::ConstraintViolation or something similar, but constraint violations on multiple keys get mapped as generic Sequel::DatabaseErrors. See https://github.com/jeremyevans/sequel/issues/782
            expect { alien_mapper.insert(another_alien) }.to raise_error(Sequel::DatabaseError)
          end
        end

        describe '#update' do
          it 'Does not allow updating the fields in a BaseValue' do
            alien_h[:hostility_level] = 110

            expect {
              alien_mapper.update(Alien.new(alien_h.dup), an_alien)
            }.to raise_error(Dilithium::PersistenceExceptions::ImmutableObjectError)
          end
        end

        describe '#delete' do
          it 'Deletes a BaseValue from the DB' do
            alien_mapper.delete(an_alien)

            modified_h = $database[:aliens].where(race: alien_h[:race], subrace: alien_h[:subrace]).first
            expect(modified_h[:active]).to be_false
          end
        end
      end
    end

    describe 'ValueRepository' do
      before(:each) do
        SchemaUtils::Sequel.create_tables(Alien, Planet)
        all_aliens.each { |alien| Mapper::Sequel.mapper_for(Alien).insert(alien) }
        Mapper::Sequel.mapper_for(Planet).insert(a_planet)
      end

      after(:each) do
        $database.drop_table :aliens
        $database.drop_table :planets
      end

      let(:planet_h) { {iso2: 'NU', iso3:'NRU', name:'Nibiru', type:'Y', active:true} }

      let(:alien_h) { {race: 'Dalek', subrace: 'Soldier', hostility_level: 85, active:true} }

      let(:another_alien_h) { {race: 'Cyberman', subrace: 'Soldier', hostility_level: 80, active:true} }

      let(:inactive_alien_h) { {race: 'Cyberman', subrace: 'Original', hostility_level: 60, active:false} }

      let(:a_planet) { Planet.new(planet_h.dup) }

      let(:an_alien) { Alien.new(alien_h.dup) }

      let(:another_alien) { Alien.new(another_alien_h.dup) }

      let(:inactive_alien) { Alien.new(inactive_alien_h.dup) }

      let(:all_aliens) { [an_alien, another_alien, inactive_alien] }

      let(:alien_repo) { Repository.for(Alien) }

      let(:planet_repo) { Repository.for(Planet) }

      describe 'Repository::for' do
        it 'Returns a Repository for the given BaseValue class' do
          expect(alien_repo).to be_a(Repository::Sequel::ValueRepository)
          expect(planet_repo).to be_a(Repository::Sequel::ValueRepository)
        end
      end

      describe 'ValueRepository' do
        describe '#fetch_by_id' do
          it 'retrieves a BaseValue when identified by a single key' do
            planet = planet_repo.fetch_by_id('NU')
            expect(planet).to eq(a_planet)
          end

          it 'retrieves a BaseValue when identified by a compound key' do
            alien = alien_repo.fetch_by_id('Dalek', 'Soldier')
            expect(alien).to eq(an_alien)
          end

          it 'retrieves all instances of the given BaseValue' do
            aliens = alien_repo.fetch_all
            expect(aliens).to eq(all_aliens)
          end
        end
      end
    end

    describe 'In a transaction' do
      let(:transaction) { UnitOfWork::Transaction.new(Mapper::Sequel) }

      let(:davros) { Alien.new(race: 'Kaled', subrace: 'Dalek hybrid', hostility_level: 100) }

      before(:each) do
        SchemaUtils::Sequel.create_tables(Alien, Planet)
      end

      after(:each) do
        $database.drop_table :aliens
        $database.drop_table :planets
      end

      it 'Allows a BaseValue to be registered as clean, which is a no-op' do
        transaction.register_clean(davros)
        expect(transaction.fetch_all_objects).to_not include(davros)
        transaction.abort
      end

      it 'Allows a BaseValue to be registered as new and inserts it' do
        transaction.register_new(davros)
        expect(transaction.fetch_object(davros).object).to eq(davros)
        transaction.commit

        expect(Repository.for(Alien).fetch_by_id(davros.race, davros.subrace)).to eq(davros)
        transaction.complete
      end

      it 'Does not a BaseValue to be registered as deleted' do
        transaction.register_new(davros)
        transaction.commit

        expect(Repository.for(Alien).fetch_by_id(davros.race, davros.subrace).active).to be_true

        transaction.register_deleted(davros)
        transaction.commit

        expect(Repository.for(Alien).fetch_by_id(davros.race, davros.subrace)).to be_nil

        transaction.complete
      end

      it 'Does not allow a BaseValue to be registered as dirty' do
        expect { transaction.register_dirty(davros) }.to raise_error(ArgumentError)
      end
    end
  end

  describe 'as a BaseEntity attribute' do
    let(:skaro) { Planet.new(iso2: 'SK', iso3: 'SKR', name: 'Skaro', type: 'K') }

    let(:davros) { Alien.new(race: 'Kaled', subrace: 'Dalek hybrid', hostility_level: 100) }

    let(:dalek_emperor) { Alien.new(race: 'Dalek', subrace: 'Emperor', hostility_level: 95) }

    describe 'BaseEntity#attribute' do
      let(:species) {
        Class.new(BaseEntity) do
          attribute :name, String
          attribute :origin, Planet
          attribute :leader, Alien
        end
      }

      let(:dalek) { species.new(name: 'Dalek', origin: skaro, leader: davros) }

      it 'Creates a new attribute entry in the BaseEntity' do
        expect(species.attribute_descriptors).to include(:origin, :leader)

        origin = species.self_attribute_descriptors[:origin]
        expect(origin).to be_a(BasicAttributes::ValueReference)
        expect(origin.name).to eq(:origin)
        expect(origin.type).to eq(Planet)

        leader = species.self_attribute_descriptors[:leader]
        expect(leader).to be_a(BasicAttributes::ValueReference)
        expect(leader.name).to eq(:leader)
        expect(leader.type).to eq(Alien)
      end

      it 'Adds accesors and mutators' do
        expect(dalek.origin).to eq(skaro)
        expect(dalek.leader).to eq(davros)
        expect(dalek).to respond_to(:name, :origin, :leader, :origin=, :leader=)

        dalek.leader = dalek_emperor
        expect(dalek.leader).to eq(dalek_emperor)
      end

      it 'Copies the reference to the BaseValue when creating an immutable copy' do
        frozen = dalek.immutable
        expect(frozen.origin).to eq(dalek.origin)
        expect(frozen.leader).to eq(dalek.leader)
      end

      describe '#initialize' do
        before(:each) do
          SchemaUtils::Sequel.create_tables(Planet, Alien)
          Mapper::Sequel.mapper_for(Planet).insert(skaro)
          Mapper::Sequel.mapper_for(Alien).insert(davros)
        end

        after(:each) do
          $database.drop_table(:planets)
          $database.drop_table(:aliens)
        end

        it 'Is constructed from a Hash, retrieving the BaseValue\'s attributes from the DB' do
          dalek2 = species.new(name: 'Dalek',
                               origin: {iso2: 'SK'},
                               leader: {race: 'Kaled', subrace: 'Dalek hybrid'})

          expect(dalek2.origin).to eq(skaro)
          expect(dalek2.leader).to eq(davros)
        end

        it 'Raises an exception if a nonpersisted BaseValue is referenced from the constructing Hash' do
          expect {
            species.new(name: 'Dalek',
                        origin: {iso2: 'MO'},
                        leader: {race: 'Cyberman', subrace: 'Cyber controller'})
          }.to raise_error(PersistenceExceptions::NotFound)
        end
      end
    end

    describe 'persistence' do
      before(:all) do
        class Species < BaseEntity
          attribute :name, String
          attribute :origin, Planet
          attribute :leader, Alien
        end
      end

      let(:dalek) { Species.new(name: 'Dalek', origin: skaro, leader: davros) }

      let(:renegade_dalek) { Species.new(name: 'Renegade dalek', origin: skaro, leader: dalek_emperor) }

      before(:each) do
        SchemaUtils::Sequel.create_tables(Planet, Alien, Species)
        Mapper::Sequel.mapper_for(Planet).insert(skaro)
        Mapper::Sequel.mapper_for(Alien).insert(davros)
      end

      after(:each) do
        $database.drop_table :species
        $database.drop_table :aliens
        $database.drop_table :planets
      end

      describe '#create_tables' do
        it 'Creates the tables' do
          $database.table_exists?(:species).should be_true
        end

        it 'Creates the tables with the proper columns' do
          expect(SchemaUtils::Sequel.get_schema(:species)).to eq(
                                                                id: {type: 'integer', primary_key: true},
                                                                active: {type: 'boolean', primary_key: false},
                                                                _version_id: {type: 'integer', :primary_key=>false},
                                                                name: {type: 'varchar(255)', primary_key: false},
                                                                origin_iso2: {type: 'varchar(255)', primary_key: false},
                                                                leader_race: {type: 'varchar(255)', primary_key: false},
                                                                leader_subrace: {type: 'varchar(255)', primary_key: false}

                                                              )

        end
      end

      describe '#insert' do
        it 'inserts foreign keys' do
          id = Mapper::Sequel.mapper_for(Species).insert(dalek)

          result_h = $database[:species].where(id: id).first
          expect(result_h[:origin_iso2]).to eq(skaro.iso2)
          expect(result_h[:leader_race]).to eq(davros.race)
          expect(result_h[:leader_subrace]).to eq(davros.subrace)
        end

        it 'raises an exception when trying to insert a nonpersisted BaseValue' do
          expect {
            Mapper::Sequel.mapper_for(Species).insert(renegade_dalek)
          }.to raise_error(PersistenceExceptions::NotFound)
        end
      end

      describe '#update' do
        it 'updates foreign keys' do
          Mapper::Sequel.mapper_for(Alien).insert(dalek_emperor)
          id = Mapper::Sequel.mapper_for(Species).insert(renegade_dalek)

          result_h = $database[:species].where(id: id).first
          expect(result_h[:leader_race]).to eq(dalek_emperor.race)
          expect(result_h[:leader_subrace]).to eq(dalek_emperor.subrace)
        end

        it 'raises an exception when trying to update with a nonpersisted BaseValue' do
          supreme_dalek = Alien.new(race: 'Dalek', subrace: 'Supreme Dalek', hostility_level: 99)
          renegade_dalek.leader = supreme_dalek

          expect {
            Mapper::Sequel.mapper_for(Species).insert(renegade_dalek)
          }.to raise_error(PersistenceExceptions::NotFound)
        end
      end
    end
  end
end

