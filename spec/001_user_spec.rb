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
    User.fetch_by_email('bob@example.net').name.should eq('Bob')
    User.fetch_by_name('Charly').id.should eq(3)
  end

  it "does not allow persistence operations without being assigned to a Transaction" do
    pending "not implemented yet"
  end

  after(:all) do
    delete_test_users
  end
end

