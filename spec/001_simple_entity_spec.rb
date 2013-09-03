describe 'A Simple Entity' do

  before(:all) do
    Mapper::Sequel.create_tables(Reference, User)
    insert_test_users
  end

  before_attrs = User.attributes

  it "is not messed with by another entities" do
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
    User.fetch_by_name('Norbert').first.email.should eq('norb@example.net')
    User.fetch_by_name('Dilbert').first.email.should eq('dilbert@example.net')
  end

  after(:all) do
    delete_test_users
  end
end

