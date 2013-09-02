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

  after(:all) do
    delete_test_refs
  end

end