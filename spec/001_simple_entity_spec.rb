require_relative 'spec_base'

describe 'A Simple Entity' do

  before(:all) do
    Mapper::Sequel.create_tables(Reference, User)
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
    expect {User.new({name:1337})}.to raise_error(RuntimeError)
    expect {User.new({reference:'not a reference'})}.to raise_error(RuntimeError)
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

  it 'fetches references' do
    references = $database[:references]
    users = $database[:users]

    references.insert(:name => 'Duke ref', :active=>true)
    references.insert(:name => 'Foo ref')
    users.insert(:name => 'Duke', :email => 'duke@example.net', :reference_id => 1, :refers_to_id => 2, :active=>true)

    duke = User.fetch_by_email('duke@example.net').first
    duke.reference.should be_a(Reference)
    duke.reference.id.should eq(1)
    duke.refers_to.should be_a(Reference)
    duke.refers_to.id.should eq(2)
  end

  it 'has not parent reference' do
    user = User.fetch_by_id(1)
    user.class.parent_reference.should eq(nil)
  end

  it "accepts empty or full-hash constructors and validates its attributes" do

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
    expect {new_user.reference = 'foo'}.to raise_error(RuntimeError)
    new_user.reference = my_reference

    expect {another_user.email = 42}.to raise_error(RuntimeError)
    expect {another_user.name = 1337}.to raise_error(RuntimeError)
    expect {User.new({:name => 'Catbert', :email => 1337})}.to raise_error(RuntimeError)
    expect {User.new({:name => nil, :email => 'catbert@example.net'})}.to raise_error(RuntimeError)

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

    transaction = UnitOfWork::Transaction.new(Mapper::Sequel)

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

  it 'can be fully serialized' do
    pending 'Implement BasicEntityBuilder'
    a_user = User.fetch_by_id(1)
    EntitySerializer.to_nested_hash(a_user).should eq({
                                                       :name => 'Alice',
                                                       :email => 'alice@example.net',
                                                       :tstamp=> '2013-09-23T18:42:14+02:00',
                                                       :password=>'$2a$10$hqlENYeHZYy9eYHnZ2ONH.5N9qnXV9uzXA/h27XCMq5HBytCLo6bm',
                                                       :active=>true
                                                    })
  end

  it 'can return an immutable copy of itself' do
    users = $database[:users]
    users.insert(:name => 'Zaphod', :email => 'zaphod@example.net', :reference_id => 1, :refers_to_id => 2, :active=>true)

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
    delete_test_users
  end
end

