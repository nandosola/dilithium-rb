# -*- encoding : utf-8 -*-
require_relative 'spec_base'
require 'lib/uow/states'
require 'lib/uow/object_tracker'

describe 'The object tracker' do

  before :all do
    DatabaseUtils.create_tables(Shipment, Container, Shipyard, Package, Location)

    module ObjectTrackerSpec

      class Qux < BaseEntity
        attribute :name, String
      end
      class Bat < BaseEntity
        attribute :name, String
        reference :qux, Qux
      end
      class Baz < BaseEntity
        attribute :name, String
        reference :bat, Bat
      end
      class Bar < BaseEntity
        attribute :name, String
        reference :baz, Baz
      end
      class Foo < BaseEntity
        attribute :name, String
        reference :bar, Bar
      end
    end

  end

  it 'method #fetch_in_dependency_order(STATE_NEW) should fetch entities in STATE_NEW in order of dependency' do

    st_new = UnitOfWork::States::Default::STATE_NEW

    a_bat = ObjectTrackerSpec::Bat.new(name:'Bat')
    a_baz = ObjectTrackerSpec::Baz.new(name:'Baz', bat:a_bat)
    a_bar = ObjectTrackerSpec::Bar.new(name:'Bar', baz:a_baz)
    a_foo = ObjectTrackerSpec::Foo.new(name:'Foo', bar:a_bar)

    object_tracker = UnitOfWork::ObjectTracker.new(UnitOfWork::States::Default::ALL_STATES)
    # Do not track in order:
    object_tracker.track(a_bar, st_new)
    object_tracker.track(a_bat, st_new)
    object_tracker.track(a_baz, st_new)
    object_tracker.track(a_foo, st_new)

    insertion_order = [a_bat, a_baz, a_bar, a_foo]
    results = object_tracker.fetch_in_dependency_order(st_new).map { |sr| sr.object }
    results.should eq(insertion_order)

    a_qux = ObjectTrackerSpec::Qux.new(name:'Qux')
    a_bat.qux = a_qux
    expect {object_tracker.fetch_in_dependency_order(st_new)}.
      to raise_error(UnitOfWork::ObjectTrackerExceptions::UntrackedObjectException)
  end

  it 'correctly handles multi references' do
    transaction = UnitOfWork::Transaction.new(Mapper::Sequel)

    st_new = UnitOfWork::States::Default::STATE_NEW

    new_shipment = Shipment.new
    new_shipment.name = "Test shipment"
    container_1 = Container.new(kind:'20ft')
    container_2 = Container.new(kind:'40fthc')
    new_shipment.add_container container_1
    new_shipment.add_container container_2

    new_shipment._version.object_id.should eq(new_shipment.containers[0]._version.object_id)
    new_shipment._version.object_id.should eq(new_shipment.containers[1]._version.object_id)

    transaction.register_new(new_shipment)
    transaction.commit

    new_shipment._version.object_id.should eq(new_shipment.containers[0]._version.object_id)
    new_shipment._version.object_id.should eq(new_shipment.containers[1]._version.object_id)

    a_shipyard = Shipyard.new
    a_shipyard.name = "Test shipyard"
    a_shipyard.reference_container Association::LazyEntityReference.new(container_1.id, Container, container_1._version)
    a_shipyard.reference_container Association::LazyEntityReference.new(container_2.id, Container, container_2._version)

    object_tracker = UnitOfWork::ObjectTracker.new(UnitOfWork::States::Default::ALL_STATES)
    object_tracker.track(new_shipment, st_new)
    object_tracker.track(a_shipyard, st_new)

    insertion_order = [new_shipment, a_shipyard]
    results = object_tracker.fetch_in_dependency_order(st_new).map { |sr| sr.object }
    results.length.should eq(insertion_order.length)
    results.each { |res| insertion_order.should include(res) }
  end
end
