require_relative 'spec_base'

describe 'A Chained Reference' do

  before(:all) do
    Mapper::Sequel.create_tables(FooRef, BarRef, BazRef, BatRef, Qux)
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
    qux_1 = Qux.fetch_by_id(1)
    bat_1 = BatRef.fetch_by_id(1)

    a_entity = MyEntity.new({description:'dependent side', baz_ref:baz_1, qux:qux_1, bat_ref:bat_1})

    transaction.register_new(a_entity)
    transaction.commit
    baz_2 = BazRef.fetch_by_id(2)
    a_entity.baz_ref = baz_2
    transaction.commit
    transaction.complete

    my_entity = MyEntity.fetch_by_id(1)
    my_entity.baz_ref.bar_ref.description.should eq('bar ref 2')
  end

  it 'should handle circular relations correctly' do
    pending
  end

  it 'should be deeply serialized' do
    my_entity = MyEntity.fetch_by_id(1)

    h = EntitySerializer.to_nested_hash(my_entity)
    h.should eq(
                 {:id=>1,
                  :active=>true,
                  :description=>"dependent side",
                  :bat_ref=>{:id=>1, :active=>true, :name=>"bat ref", :qux=>{:id=>1, :active=>true, :name=>"qux 1"}},
                  :qux=>{:id=>1, :active=>true, :name=>"qux 1"},
                  :baz_ref=>
                      {:id=>2,
                       :active=>true,
                       :description=>"baz ref 2",
                       :bar_ref=>
                           {:id=>2,
                            :active=>true,
                            :description=>"bar ref 2",
                            :foo_ref=>{:id=>1, :active=>true, :description=>"foo ref"}}}}
             )

  end

  after(:all) do
    delete_test_refs
  end

end
