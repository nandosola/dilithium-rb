# -*- encoding : utf-8 -*-
require_relative 'spec_base'

describe 'A transaction handling a Simple Entity' do
  before(:all) do
    SchemaUtils::Sequel.create_tables(Reference, User)
    insert_test_users

    class UnitOfWork::Transaction
      # exposed ONLY for testing purposes
      def tracked_objects
        @object_tracker
      end
    end
    @transaction = UnitOfWork::Transaction.new(EntityMapper::Sequel)
    @a_user = User.fetch_by_id(1)
    @b_user = User.fetch_by_id(2)
    @new_user = User.new
  end

  it "has a unique identifier" do
    @transaction.uuid.should =~ /^[0-9a-f]{32}$/
  end

  it "correctly registers itself into the Registry" do
    UnitOfWork::TransactionRegistry::Registry.instance[@transaction.uuid.to_sym].should eq(@transaction)
  end

  it "won't get registered if the model is not a BasicEntity" do
    class NotABasicEntity
    end
    expect {@transaction.register_new(NotABasicEntity.new)}.to raise_error(ArgumentError)
  end

  it "correctly registers an object with a Transaction" do
    @transaction.register_clean(@a_user)

    found_tracked_objects = @transaction.tracked_objects.fetch_by_state(UnitOfWork::Transaction::STATE_CLEAN)
    found_tracked_objects.size.should eq(1)
    found_tracked_objects.first.object.should eq(@a_user)

    u = @transaction.fetch_object(@a_user)
    u.object.should_not be_nil
    u.state.should eq(UnitOfWork::Transaction::STATE_CLEAN)
  end

  it "correctly unregisters an object with a Transaction" do
    @transaction.unregister(@a_user)
    found_objects = @transaction.fetch_all_objects
    found_objects.size.should eq(0)

    expect{@transaction.unregister(@a_user)}.to raise_error(NameError)

    @transaction.register_clean(@a_user)
    found_objects = @transaction.fetch_all_objects
    found_objects.size.should eq(1)
    found_objects.first.object.should eq(@a_user)
  end

  it "fetches a specific tracked object from the tracked object's class and its id" do
    @transaction.fetch_object_by_id(@a_user.class, @a_user.id).object.should eq(@a_user)
    @transaction.fetch_object_by_id(@a_user.class, 42).should be_nil

    @transaction.fetch_object(@a_user).object.should eq(@a_user)

    reg = UnitOfWork::TransactionRegistry::Registry.instance
    reg['c0ffeeb4b3'].should be_a_kind_of(UnitOfWork::TransactionRegistry::Registry::TransactionNotFound)
  end

  it "correctly moves an object between states" do
    @a_user.name= 'Andrew'
    @transaction.register_dirty(@a_user)

    @transaction.tracked_objects.fetch_by_state(UnitOfWork::Transaction::STATE_CLEAN).length.should eq(0)
    found_tracked_objects = @transaction.tracked_objects.fetch_by_state(UnitOfWork::Transaction::STATE_DIRTY)
    found_tracked_objects.size.should eq(1)
    found_tracked_objects.first.object.should eq(@a_user)

    res = @transaction.fetch_object(@a_user)
    res.should_not be_nil
    res.state.should eq(UnitOfWork::Transaction::STATE_DIRTY)
  end

  it "correctly saves changes to dirty objects when calling commit" do
    @transaction.commit
    @transaction.valid.should eq(true)

    @transaction.tracked_objects.fetch_by_state(UnitOfWork::Transaction::STATE_DIRTY).length.should eq(1)
    @transaction.tracked_objects.fetch_by_state(UnitOfWork::Transaction::STATE_DIRTY)[0].object.should eq(@a_user)
    @transaction.valid.should eq(true)

    @a_user.name.should eq('Andrew')
  end

  it "deletes objects registered for deletion when calling commit" do
    @transaction.register_deleted(@a_user)

    @transaction.tracked_objects.fetch_by_state(UnitOfWork::Transaction::STATE_DIRTY).length.should eq(0)
    @transaction.tracked_objects.fetch_by_state(UnitOfWork::Transaction::STATE_DELETED)[0].object.should eq(@a_user)

    @transaction.commit

    User.fetch_by_id(1).should be_nil
    @transaction.tracked_objects.fetch_by_state(UnitOfWork::Transaction::STATE_DELETED).length.should eq(0)
  end

  it "saves new objects and marks them as dirty when calling commit" do
    @transaction.register_new(@new_user)
    @new_user.make({name:'Danny', email:'danny@example.net' })

    found_tracked_objects = @transaction.tracked_objects.fetch_by_state(UnitOfWork::Transaction::STATE_NEW)
    found_tracked_objects.size.should eq(1)
    found_tracked_objects.first.object.should eq(@new_user)

    @transaction.commit
    User.fetch_by_name('Danny').should_not be_empty

    res = @transaction.fetch_object(@new_user)
    res.should_not be_nil
    res.object.should eq(@new_user)
    res.state.should eq(UnitOfWork::Transaction::STATE_DIRTY)

    user = res.object
    user.name = 'Franny'
    @transaction.commit

    User.fetch_by_name('Franny').should_not be_empty
    User.fetch_by_name('Danny').should be_empty

  end

  it "removes deleted objects from the transaction when calling commit" do
    @transaction.register_deleted(@new_user)
    @transaction.commit
    User.fetch_by_name('Danny').should be_empty
    found_tracked_object = @transaction.tracked_objects.fetch_object(@new_user)
    found_tracked_object.should be_nil
  end

  it "does not affect objects when calling rollback" do
    @a_user = User.fetch_by_id(2)
    @transaction.register_dirty(@a_user)
    @a_user.name = 'Bartley'
    expect {@transaction.register_dirty(@a_user)}.to raise_error(ArgumentError)
    @transaction.rollback

    @transaction.valid.should eq(true)
    @transaction.tracked_objects.fetch_by_state(UnitOfWork::Transaction::STATE_DIRTY).length.should eq(1)
    @transaction.tracked_objects.fetch_by_state(UnitOfWork::Transaction::STATE_DIRTY)[0].object.should eq(@a_user)
    @transaction.valid.should eq(true)

    @a_user.name.should eq('Bob')

  end

  it "registers objects in the glabal Registry and allows them to be found" do
    a=[]
    reg = UnitOfWork::TransactionRegistry::Registry.instance
    reg.each_entity(@transaction.uuid) do |e|
      a<<e
    end
    b = @transaction.tracked_objects.fetch_all

    a.size.should eq(1)
    b.size.should eq(1)
    b[0].object.should eq(a[0].object)
  end

  it "cannot register an model that already exists in the transaction" do
    user = User.fetch_by_id(2)
    expect {@transaction.register_dirty(user)}.to raise_error(ArgumentError)

    new_tr = UnitOfWork::Transaction.new(EntityMapper::Sequel)
    expect {new_tr.register_new(user)}.to raise_error(ArgumentError)

    new_user = User.new
    new_tr.register_new(new_user)
    expect {new_tr.register_new(new_user)}.to raise_error(ArgumentError)

    another_user = User.new
    new_tr.register_new(another_user)

  end

  it "sets deleted objects to dirty and reloads dirty and deleted objects when calling rollback" do
    pending
  end

  it "does not allow calling complete if there are pending commits or rollbacks" do
    pending
  end

  it "empties, invalidates and unregisters the Transaction when calling complete" do
    pending
  end

  after(:all) do
    %i(users references _versions).each do |t|
      $database.drop_table t
      $database << "DELETE FROM SQLITE_SEQUENCE WHERE NAME = '#{t}'"
    end
  end
end
