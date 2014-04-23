# -*- encoding : utf-8 -*-
require_relative 'spec_base'
require 'fixtures/simple_entity'
require 'fixtures/leaf_table_inheritance'


describe 'BaseEntityMassUpdater' do

  describe '#update!' do
    let(:test_payload){
      Class.new do
        include BaseEntityPayload
        def initialize(in_h)
          @payload = in_h
        end
        def content
          @payload
        end
      end
    }

    context 'Simple entities (without children)' do
      it 'updates attributes' do
        user = User.build do |u|
          u.id = 42
          u.name = 'PHB'
          u.email = 'phb@example.net'
        end

        payload = test_payload.new({id:42, :name => 'Dogbert', :email => 'dogbert@example.net'})
        BaseEntityMassUpdater.new(user, payload).update!
        expect(user.id).to eq(42)
        expect(user.name).to eq('Dogbert')
        expect(user.email).to eq('dogbert@example.net')

        payload = test_payload.new({id:42, :name => 'Catbert'})
        BaseEntityMassUpdater.new(user, payload).update!
        expect(user.id).to eq(42)
        expect(user.name).to eq('Catbert')
        expect(user.email).to be_nil

        payload = test_payload.new({id:42, :name => 'Ratbert', :email => nil})
        BaseEntityMassUpdater.new(user, payload).update!
        expect(user.id).to eq(42)
        expect(user.name).to eq('Ratbert')
        expect(user.email).to be_nil

        payload = test_payload.new({:email => 'ratbert@example.net'})
        expect {BaseEntityMassUpdater.new(user, payload).update!}.to raise_error(ArgumentError)

      end
    end

    context 'Simple entity with references' do
      it 'updates attributes and references' do
        foo_ref = Reference.build do |r|
          r.name = 'foo_ref'
        end
        user = User.build do |u|
          u.name = 'Perry'
          u.email = 'perry@example.net'
          u.reference = foo_ref
        end

        bar_ref = Reference.build do |r|
          r.name = 'bar_ref'
        end
        payload = test_payload.new({:name => 'Wally', :email => 'wally@example.net', :reference => bar_ref })
        BaseEntityMassUpdater.new(user, payload).update!
        expect(user.name).to eq('Wally')
        expect(user.email).to eq('wally@example.net')
        expect(user.reference.resolve.name).to eq('bar_ref')
      end
    end

    context 'Aggregate entities' do
      it 'updates the whole aggregate' do

        a_company = Company.build do |c|
          c.name = 'Smarty Pants, Inc.'
          c.make_local_office do |l|
            l.description = 'foo del 1'
            l.make_address { |a| a.description = 'foo dir 1' }
            l.make_address { |a| a.description = 'foo dir 2' }
          end
        end

        payload = test_payload.new({
                                       url: 'http://example.net',
                                       name: 'New Horizon Partners, Inc.',
                                       local_offices: [
                                           {
                                               description: 'nhp del 1',
                                               addresses: [{description: 'nhp dir 1'}]
                                           }
                                       ]})
        BaseEntityMassUpdater.new(a_company, payload).update!
        expect(a_company.name).to eq('New Horizon Partners, Inc.')
        expect(a_company.url).to eq('http://example.net')
        expect(a_company.local_offices[0].description).to eq('nhp del 1')
        expect(a_company.local_offices[0].addresses[0].description).to eq('nhp dir 1')


        payload = test_payload.new({
                                       url: 'http://example.net',
                                       name: 'New Horizon Partners, Inc.',
                                       local_offices: [
                                           {
                                               description: 'nhp del 1',
                                               addresses: []
                                           }
                                       ]})
        BaseEntityMassUpdater.new(a_company, payload).update!
        expect(a_company.name).to eq('New Horizon Partners, Inc.')
        expect(a_company.url).to eq('http://example.net')
        expect(a_company.local_offices[0].description).to eq('nhp del 1')
        expect(a_company.local_offices[0].addresses.empty?).to be_true

        payload = test_payload.new({
                                       url: 'http://example.net',
                                       name: 'New Horizon Partners, Inc.',
                                       local_offices: []})
        BaseEntityMassUpdater.new(a_company, payload).update!
        expect(a_company.name).to eq('New Horizon Partners, Inc.')
        expect(a_company.url).to eq('http://example.net')
        expect(a_company.local_offices.empty?).to be_true

        payload = test_payload.new({
                                       url: 'http://example.net',
                                       name: 'New Horizon Partners, Inc.',
                                       local_offices: nil})
        BaseEntityMassUpdater.new(a_company, payload).update!
        expect(a_company.name).to eq('New Horizon Partners, Inc.')
        expect(a_company.url).to eq('http://example.net')
        expect(a_company.local_offices.empty?).to be_true

      end
    end

    context 'Aggregate with polymorphic children' do
      it 'updates the whole aggregate taking care of the polymorphism' do
        fleet = FleetL.build_empty
        expect(fleet.ground_vehicle_ls.empty?).to be_true

        in_h = {:fleet_l=>{ :name=>'6th fleet',
                             :ground_vehicle_ls=> [
                                 {:seats=>2, :wheels=>4, :name=>'Mazda MX5', :_type=>'car_l'},
                                 {:capacity=>200, :wheels=>3, :name=>'Tuk Tuk', :_type=>'delivery_van_l'}
                             ]}}
        payload = test_payload.new(in_h[:fleet_l])
        BaseEntityMassUpdater.new(fleet, payload).update!
        expect(fleet.name).to eq('6th fleet')
        expect(fleet.ground_vehicle_ls.size).to eq(2)
        expect(fleet.ground_vehicle_ls[0]).to be_a(CarL)
        expect(fleet.ground_vehicle_ls[0].seats).to eq(2)
        expect(fleet.ground_vehicle_ls[0].wheels).to eq(4)
        expect(fleet.ground_vehicle_ls[0].name).to eq('Mazda MX5')

        expect(fleet.ground_vehicle_ls[1]).to be_a(DeliveryVanL)
        expect(fleet.ground_vehicle_ls[1].capacity).to eq(200)
        expect(fleet.ground_vehicle_ls[1].wheels).to eq(3)
        expect(fleet.ground_vehicle_ls[1].name).to eq('Tuk Tuk')

      end
    end

    context 'Aggregate with polymorphic children and references' do
      it 'updates the whole aggregate taking care of the polymorphism and the references' do
        fleet = FleetL.build_empty
        expect(fleet.ground_vehicle_ls.empty?).to be_true

        phil = User.build do |u|
          u.name = 'Phil Tremaine'
          u.email = 'phil@example.net'
        end

        class CarL < GroundVehicleL
          reference :owner, User
        end

        in_h = {:fleet_l=>{ :name=>'6th fleet',
                            :ground_vehicle_ls=> [
                                {:seats=>2, :wheels=>4, :name=>'Mazda MX5', :owner=>phil, :_type=>'car_l'},
                            ]}}

        payload = test_payload.new(in_h[:fleet_l])
        BaseEntityMassUpdater.new(fleet, payload).update!
        expect(fleet.ground_vehicle_ls[0]).to be_a(CarL)
        expect(fleet.ground_vehicle_ls[0].seats).to eq(2)
        expect(fleet.ground_vehicle_ls[0].wheels).to eq(4)
        expect(fleet.ground_vehicle_ls[0].name).to eq('Mazda MX5')
        expect(fleet.ground_vehicle_ls[0].owner.resolve.name).to eq('Phil Tremaine')

      end
    end


  end

end