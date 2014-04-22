# -*- encoding : utf-8 -*-
require_relative 'spec_base'
require 'lib/uow/states'
require 'lib/uow/object_tracker'

describe 'The object tracker' do

  before :all do
    SchemaUtils::Sequel.create_tables(Shipment, Container, Shipyard, Package, Location)

    class OtQux < BaseEntity
      attribute :name, String
    end
    class OtBat < BaseEntity
      attribute :name, String
      reference :ot_qux, OtQux
    end
    class OtBaz < BaseEntity
      attribute :name, String
      reference :ot_bat, OtBat
    end
    class OtBar < BaseEntity
      attribute :name, String
      reference :ot_baz, OtBaz
    end
    class OtFoo < BaseEntity
      attribute :name, String
      reference :ot_bar, OtBar
    end
  end

  describe '#fetch_by_identifier' do
    it 'gets a single tregistered object' do
      a_qux = OtQux.build do |qux|
        qux.name = 'test'
      end
      a_bat = OtBat.build do |bat|
        bat.name = 'test'
        bat.ot_qux  = a_qux
      end

      object_tracker = UnitOfWork::ObjectTracker.new([:A,:B])
      id1 = object_tracker.track(a_qux, :A)
      id2 = object_tracker.track(a_bat, :B)

      expect(object_tracker.fetch_by_identifier(id1).object.object_id).to eq(a_qux.object_id)
      expect(object_tracker.fetch_by_identifier(id2).object.object_id).to eq(a_bat.object_id)
    end
  end

  describe '#fetch_in_dependency_order' do
    context '(STATE_NEW)' do
      it ' should fetch entities in STATE_NEW in order of dependency' do

        st_new = UnitOfWork::States::Default::STATE_NEW

        a_bat = OtBat.build { |b| b.name = 'Bat' }
        a_baz = OtBaz.build do |b|
          b.name = 'Baz'
          b.ot_bat = a_bat
        end

        a_bar = OtBar.build do |b|
          b.name = 'Bar'
          b.ot_baz = a_baz
        end

        a_foo = OtFoo.build do |b|
          b.name = 'Foo'
          b.ot_bar = a_bar
        end

        object_tracker = UnitOfWork::ObjectTracker.new(UnitOfWork::States::Default::ALL_STATES)
        # Do not track in order:
        object_tracker.track(a_bar, st_new)
        object_tracker.track(a_bat, st_new)
        object_tracker.track(a_baz, st_new)
        object_tracker.track(a_foo, st_new)

        insertion_order = [a_bat, a_baz, a_bar, a_foo]
        results = object_tracker.fetch_in_dependency_order(st_new).map { |sr| sr.object }
        results.should eq(insertion_order)

        a_qux = OtQux.build { |q| q.name = 'Qux' }
        a_bat.ot_qux = a_qux
        expect {object_tracker.fetch_in_dependency_order(st_new)}.
            to raise_error(UnitOfWork::ObjectTrackerExceptions::UntrackedObjectException)
      end

      it 'correctly handles multi references' do
        transaction = UnitOfWork::Transaction.new(EntityMapper::Sequel)

        st_new = UnitOfWork::States::Default::STATE_NEW

        new_shipment = Shipment.build do |s|
          s.make_container { |c| c.kind = '20ft' }
          s.make_container { |c| c.kind = '40fthc' }
        end

        new_shipment._version.object_id.should eq(new_shipment.containers[0]._version.object_id)
        new_shipment._version.object_id.should eq(new_shipment.containers[1]._version.object_id)

        transaction.register_new(new_shipment)
        transaction.commit

        new_shipment._version.object_id.should eq(new_shipment.containers[0]._version.object_id)
        new_shipment._version.object_id.should eq(new_shipment.containers[1]._version.object_id)

        a_shipyard = Shipyard.build do |s|
          s.name = 'Test shipyard'
          new_shipment.containers.each { |c| s.add_container(c) }
        end

        object_tracker = UnitOfWork::ObjectTracker.new(UnitOfWork::States::Default::ALL_STATES)
        object_tracker.track(new_shipment, st_new)
        object_tracker.track(a_shipyard, st_new)

        insertion_order = [new_shipment, a_shipyard]
        results = object_tracker.fetch_in_dependency_order(st_new).map { |sr| sr.object }
        results.length.should eq(insertion_order.length)
        results.each { |res| insertion_order.should include(res) }
      end

    end
  end


end
