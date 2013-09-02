describe 'A Chained Reference' do

  before(:all) do
    Mapper::Sequel.create_tables(FooRef, BarRef, BazRef)
    insert_test_refs
  end

  it 'should be exploded by the Repository' do
    a_baz = BazRef.fetch_by_id(1)
    a_baz.bar_ref.description.should eq('bar ref')
    a_baz.bar_ref.foo_ref.description.should eq('foo ref')
  end

  it 'should persist only the dependent side' do
    Mapper::Sequel.create_tables(MyEntity)
    transaction = UnitOfWork::Transaction.new(Mapper::Sequel)

    expect {MyEntity.new({description:'dependent side', baz_ref_id:1})}.to raise_error(ArgumentError)

    baz_1 = BazRef.fetch_by_id(1)
    a_entity = MyEntity.new({description:'dependent side', baz_ref:baz_1})

    transaction.register_new(a_entity)
    transaction.commit
    baz_2 = BazRef.fetch_by_id(2)
    a_entity.baz_ref = baz_2
    transaction.commit
    transaction.complete

    MyEntity.fetch_by_id(1).baz_ref.bar_ref.description.should eq('bar ref 2')
  end

  after(:all) do
    delete_test_refs
  end

end