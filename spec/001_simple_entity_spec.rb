describe User do

  before(:all) do
    insert_test_users
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

  it "does not allow persistence operations without being assigned to a Unit of Work" do
    norbert = {:name => 'Norbert', :email => 'norb@example.net'}
    new_user = User.new(norbert)
    expect {new_user.create}.to raise_error(RuntimeError)
    transaction = UnitOfWork::Transaction.new
    transaction.register_new(new_user)
    transaction.commit
    transaction.complete
    User.fetch_by_name('Norbert').first.email.should eq('norb@example.net')
  end

  after(:all) do
    delete_test_users
  end
end

