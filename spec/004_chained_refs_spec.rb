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
                  :_version=>{:id=>8, :_version=>1, :_version_created_at=>my_entity._version._version_created_at,
                              :_locked_by=>nil, :_locked_at=>nil},
                  :description=>"dependent side",
                  :qux=>{:id=>1, :active=>true,
                         :_version=>{:id=>6, :_version=>0,
                         :_version_created_at=>my_entity.qux._version._version_created_at,
                         :_locked_by=>nil, :_locked_at=>nil},
                         :name=>"qux 1"},
                  :baz_ref=>
                      {:id=>2,
                       :active=>true,
                       :_version=>{:id=>5, :_version=>0,
                                   :_version_created_at=>my_entity.baz_ref._version._version_created_at,
                                   :_locked_by=>nil, :_locked_at=>nil},
                       :description=>"baz ref 2",
                       :bar_ref=>
                           {:id=>2,
                            :active=>true,
                            :_version=>{:id=>3, :_version=>0,
                                        :_version_created_at=>my_entity.baz_ref.bar_ref._version._version_created_at,
                                        :_locked_by=>nil, :_locked_at=>nil},
                            :description=>"bar ref 2",
                            :foo_ref=>{:id=>1, :active=>true,
                                       :_version=>{:id=>1, :_version=>0,
                                                   :_version_created_at=>my_entity.baz_ref.bar_ref.foo_ref._version._version_created_at,
                                                   :_locked_by=>nil, :_locked_at=>nil},
                                       :description=>"foo ref"}}},
                  :bat_ref=>{:id=>1, :active=>true,
                             :_version=>{:id=>7, :_version=>0,
                                         :_version_created_at=>my_entity.bat_ref._version._version_created_at,
                                         :_locked_by=>nil, :_locked_at=>nil},
                             :name=>"bat ref",
                             :qux=>{:id=>1,
                                    :active=>true,
                                    :_version=>{:id=>6, :_version=>0,
                                                :_version_created_at=>my_entity.qux._version._version_created_at,
                                                :_locked_by=>nil, :_locked_at=>nil},
                                    :name=>"qux 1"}}
                  }
             )

  end

  after(:all) do
    %i(my_entities bat_refs baz_refs bar_refs quxes foo_refs _versions).each do |t|
      $database.drop_table t
      $database << "DELETE FROM SQLITE_SEQUENCE WHERE NAME = '#{t}'"
    end
  end

end
