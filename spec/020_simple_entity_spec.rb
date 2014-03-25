# -*- encoding : utf-8 -*-
require_relative 'spec_base'

describe 'A Simple Entity' do

  before(:all) do
    SchemaUtils::Sequel.create_tables(Reference, User)
    insert_test_users
  end

  it "is not messed with by another entities" do
    before_attrs = User.attributes

    class AnotherThing < BaseEntity
      attribute :my_thing, String, mandatory:true
    end

    User.attributes.should eq(before_attrs)

    a_user = User.new()
    a_user.respond_to?(:id).should be_true
    a_user.respond_to?(:id=).should be_true
    a_user.respond_to?(:name).should be_true
    a_user.respond_to?(:name=).should be_true
    a_user.respond_to?(:email).should be_true
    a_user.respond_to?(:email=).should be_true
    a_user.instance_variables.include?(:'@my_thing').should be_false
    a_user.respond_to?(:my_thing).should be_false
    a_user.respond_to?(:my_thing=).should be_false
  end

  it "does not allow to be initialized with bogus attributes or values" do
    expect {User.new({funny:false})}.to raise_error(ArgumentError)
    expect {User.new({name:1337})}.to raise_error(ArgumentError)
    expect {User.new({reference:'not a reference'})}.to raise_error(ArgumentError)
  end

  it "has repository finders" do
    a_user = User.fetch_by_id(1)
    a_user.class.should eq(User)
    a_user.name.should eq('Alice')
    all_users = User.fetch_all
    all_users.each do |u|
      u.class.should eq(User)
    end
    User.fetch_by_email('bob@example.net').first.name.should eq('Bob')
    User.fetch_by_name('Charly').first.id.should eq(3)
  end

  it 'raises an exception if fetch_by_id is called with a nonexistent key' do
    expect { User.fetch_by_id(42) }.to raise_error(PersistenceExceptions::NotFound)
  end

  it 'fetches references' do
    duke = User.fetch_by_email('duke@example.net').first
    duke.reference.should be_a(Association::ImmutableEntityReference)
    duke.reference._type.should eq(Reference)
    duke.reference.id.should eq(1)
    duke.reference.resolve
    duke.reference.resolved_entity.name.should eq('Duke ref')

    duke.refers_to.should be_a(Association::ImmutableEntityReference)
    duke.refers_to._type.should eq(Reference)
    duke.refers_to.id.should eq(2)
  end

  it 'has not parent reference' do
    user = User.fetch_by_id(1)
    user.class.parent_reference.should eq(nil)
  end

  it 'accepts empty or full-hash constructors and validates its attributes' do

    norbert = {:name => 'Norbert', :email => 'norb@example.net'}
    dilbert = {:name => 'Dilbert', :email => 'dilbert@example.net'}

    new_user = User.new(norbert)
    another_user= User.new()

    new_user.respond_to?(:id).should be_true
    new_user.respond_to?(:id=).should be_true
    new_user.respond_to?(:name).should be_true
    new_user.respond_to?(:name=).should be_true
    new_user.respond_to?(:email).should be_true
    new_user.respond_to?(:email=).should be_true

    my_reference = Reference.new({name:'test'})
    new_user.respond_to?(:reference).should be_true
    new_user.respond_to?(:reference=).should be_true
    my_reference.name.should eq('test')
    new_user.reference.should be_nil
    expect {new_user.reference = 'foo'}.to raise_error(ArgumentError)
    new_user.reference = my_reference

    expect {another_user.email = 42}.to raise_error(ArgumentError)
    expect {another_user.name = 1337}.to raise_error(ArgumentError)
    expect {User.new({:name => 'Catbert', :email => 1337})}.to raise_error(ArgumentError)
    expect {User.new({:name => nil, :email => 'catbert@example.net'})}.to raise_error(ArgumentError)

    another_user.make(dilbert)

    another_user.id.should eq(nil)
    another_user.name.should eq('Dilbert')
    another_user.email.should eq('dilbert@example.net')

    new_user.id.should eq(nil)
    new_user.name.should eq('Norbert')
    new_user.email.should eq('norb@example.net')

    another_user.id.should eq(nil)
    another_user.name.should eq('Dilbert')
    another_user.email.should eq('dilbert@example.net')

    transaction = UnitOfWork::Transaction.new(EntityMapper::Sequel)

    transaction.register_new(new_user)
    transaction.register_new(another_user)
    transaction.commit
    transaction.complete
    norb = User.fetch_by_name('Norbert')
    norb.first.email.should eq('norb@example.net')
    norb.first.reference.should_not be_nil
    User.fetch_by_name('Dilbert').first.email.should eq('dilbert@example.net')
  end

  it 'can be fully updated' do
    user = User.fetch_by_name('Dilbert').first
    id = user.id
    user.full_update({id:id, :name => 'Dogbert', :email => 'dogbert@example.net'})
    user.name.should eq('Dogbert')
    user.email.should eq('dogbert@example.net')

    user.full_update({id:id, :name => 'Catbert'})
    user.name.should eq('Catbert')
    user.email.should be_nil

    user.full_update({id:id, :name => 'Ratbert', :email => nil})
    user.name.should eq('Ratbert')
    user.email.should be_nil

    expect {user.full_update({:email => 'ratbert@example.net'}) }.to raise_error(ArgumentError)

  end

  pending 'Implement BasicEntityBuilder'
  it 'can be fully serialized' do
    a_user = User.fetch_by_id(1)
    test_hash ={
      :id => 1,
      :name => 'Alice',
      :email => 'alice@example.net',
      :tstamp=> DateTime.strptime('2013-09-23T18:42:14+02:00', '%Y-%m-%dT%H:%M:%S%z'),
      :password=>'$2a$10$hqlENYeHZYy9eYHnZ2ONH.5N9qnXV9uzXA/h27XCMq5HBytCLo6bm',
      :active=>true,
      :reference => nil,
      :refers_to => nil,
      :title => 'Esq.',
      :_version => {id:1, _version:0, _version_created_at:DateTime.parse('2013-09-23T18:42:14+02:00'),
                    _locked_by: nil, _locked_at: nil}
    }

    EntitySerializer.to_nested_hash(a_user).each { |k, v| test_hash[k].should eq(v) }
  end

  it 'can return an immutable copy of itself' do

    a_user = User.fetch_by_email('zaphod@example.net').first
    an_immutable_user = a_user.immutable

    an_immutable_user.should be_a(User::Immutable)

    an_immutable_user.respond_to?(:id).should be_true
    an_immutable_user.respond_to?(:id=).should be_false
    an_immutable_user.respond_to?(:name).should be_true
    an_immutable_user.respond_to?(:name=).should be_false
    an_immutable_user.respond_to?(:email).should be_true
    an_immutable_user.respond_to?(:email=).should be_false
    an_immutable_user.respond_to?(:reference).should be_false
    an_immutable_user.respond_to?(:reference=).should be_false
    an_immutable_user.respond_to?(:refers_to).should be_false
    an_immutable_user.respond_to?(:refers_to=).should be_false

    an_immutable_user.respond_to?(:my_thing).should be_false

    an_immutable_user.id.should eq(a_user.id)
    an_immutable_user.name.should eq(a_user.name)
    an_immutable_user.email.should eq(a_user.email)
  end

  after(:all) do
    %i(users references _versions).each do |t|
      $database.drop_table t
      $database << "DELETE FROM SQLITE_SEQUENCE WHERE NAME = '#{t}'"
    end
  end
end

