require_relative 'spec_base'
require 'lib/uow/states'
require 'lib/uow/object_tracker'

describe 'The object tracker' do

  before :all do

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
    object_tracker.fetch_in_dependency_order(st_new).each_with_index do |sr, idx|
      sr.object.should eq(insertion_order[idx])
    end

    a_qux = ObjectTrackerSpec::Qux.new(name:'Qux')
    a_bat.qux = a_qux
    expect {object_tracker.fetch_in_dependency_order(st_new)}.
        to raise_error(UnitOfWork::ObjectTrackerExceptions::UntrackedObjectException)
  end
end