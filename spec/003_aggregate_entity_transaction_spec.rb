require_relative 'spec_base'

describe 'A Transaction handling an Aggregate Entity' do
  before(:all) do
    Mapper::Sequel.create_tables(Company, LocalOffice, Address)
    class UnitOfWork::Transaction
      # exposed ONLY for testing purposes
      def tracked_objects
        @object_tracker
      end
    end
  end

  before(:each) do
    @transaction = UnitOfWork::Transaction.new(Mapper::Sequel)
  end

  after(:each) do
    @transaction.rollback unless @transaction.committed
    @transaction.finalize
  end

  it 'creates a new Aggregate in the database and retrieves it correctly' do
    company1_h = {
        name: 'Abstra.cc S.A',
        local_offices: [
            {
                description: 'branch1',
                addresses: [{description: 'addr1'}]
            }
        ]
    }

    a_company = Company.new(company1_h)
    @transaction.register_new(a_company)

    a_company.make_local_office({
                            description: 'branch2',
                            addresses: [{description: 'addr2.1'}]
                        })

    a_company.class.should eq(Company)
    a_company.name.should eq('Abstra.cc S.A')

    a_company.local_offices.size.should eq(2)

    a_company.local_offices[0].class.should eq(LocalOffice)
    a_company.local_offices[0].description.should eq('branch1')
    a_company.local_offices[0].addresses.size.should eq(1)
    a_company.local_offices[0].addresses[0].description.should eq('addr1')

    a_company.local_offices[1].description.should eq('branch2')
    a_company.local_offices[1].addresses[0].class.should eq(Address)
    a_company.local_offices[1].addresses[0].description.should eq('addr2.1')

    a_company.class.parent_reference.should be_nil
    a_company.local_offices[1].class.parent_reference.should eq(:company)

    @transaction.commit

    expect {a_company.make_local_office({
                                    description: 'branch3',
                                    company: 1
                                })}.to raise_error(RuntimeError)

    expect {a_company.make_local_office({
                                    description: 'branch4',
                                    addresses: [1,2,3]
                                })}.to raise_error(ArgumentError)

    abstra =  Company.fetch_by_id(1)

    abstra.class.should eq(Company)
    abstra.name.should eq('Abstra.cc S.A')
    abstra.id.should eq(1)

    abstra.local_offices.size.should eq(2)

    abstra.local_offices[0].class.should eq(LocalOffice)
    abstra.local_offices[0].description.should eq('branch1')
    abstra.local_offices[0].addresses.size.should eq(1)
    abstra.local_offices[0].addresses[0].description.should eq('addr1')

    abstra.local_offices[1].description.should eq('branch2')
    abstra.local_offices[1].addresses[0].class.should eq(Address)
    abstra.local_offices[1].addresses[0].description.should eq('addr2.1')

  end

  it "creates a new aggregate, retrieves it and performs updates" do
    company2_h = {
        name: 'Smarty Pants, Inc.',
        local_offices: [
            {
                description: 'foo del 1',
                addresses: [{description: 'foo dir 1'},
                              {description: 'foo dir 2'}]
            }
        ]
    }

    b_company = Company.new()
    b_company.make(company2_h)
    @transaction.register_new(b_company)

    @transaction.commit

    smarty_pants =  Company.fetch_by_id(2)

    smarty_pants.name.should eq('Smarty Pants, Inc.')
    smarty_pants.id.should eq(2)

    smarty_pants.local_offices.size.should eq(1)

    smarty_pants.local_offices[0].description.should eq('foo del 1')
    smarty_pants.local_offices[0].addresses.size.should eq(2)
    smarty_pants.local_offices[0].addresses[0].description.should eq('foo dir 1')
    smarty_pants.local_offices[0].addresses[1].description.should eq('foo dir 2')
    Company.fetch_all.size.should eq(2)

    b_company.full_update({id: 2,
                           url: 'http://example.net',
                           name: 'New Horizon Partners, Inc.',
                           local_offices: [
                               {
                                   description: 'nhp del 1',
                                   addresses: [{description: 'nhp dir 1'}]
                               }
                           ]})
    @transaction.commit

    new_horizon = Company.fetch_by_id(2)
    new_horizon.name.should eq('New Horizon Partners, Inc.')
    new_horizon.url.should eq('http://example.net')
    new_horizon.id.should eq(2)

    new_horizon.local_offices.size.should eq(1)

    new_horizon.local_offices[0].description.should eq('nhp del 1')
    new_horizon.local_offices[0].addresses.size.should eq(1)
    new_horizon.local_offices[0].addresses[0].description.should eq('nhp dir 1')

    b_company.full_update({id: 2,
                           url: 'http://example.net',
                           name: 'New Horizon Partners, Inc.',
                           local_offices: [
                               {
                                   description: 'nhp del 1',
                                   addresses: []
                               }
                           ]})

    @transaction.commit

    new_horizon = Company.fetch_by_id(2)
    new_horizon.local_offices.size.should eq(1)
    new_horizon.local_offices[0].addresses.size.should eq(0)

    b_company.full_update({id: 2,
                           url: 'http://example.net',
                           name: 'New Horizon Partners, Inc.',
                           local_offices: []})

    @transaction.commit

    new_horizon = Company.fetch_by_id(2)
    new_horizon.local_offices.size.should eq(0)

    b_company.full_update({id: 2,
                           url: 'http://example.net',
                           name: 'New Horizon Partners, Inc.',
                           local_offices: [
                               {
                                   description: 'nhp del 1',
                                   addresses: [{description: 'nhp dir 1'}]
                               }
                           ]})
    @transaction.commit

    new_horizon = Company.fetch_by_id(2)
    new_horizon.local_offices.size.should eq(1)

    b_company.full_update({id: 2,
                           url: 'http://example.net',
                           name: 'New Horizon Partners, Inc.',
                           local_offices: nil})

    @transaction.commit

    new_horizon = Company.fetch_by_id(2)
    new_horizon.local_offices.size.should eq(0)

    b_company.full_update({id: 2,
                           url: 'http://example.net',
                           name: 'New Horizon Partners, Inc.',
                           local_offices: [
                               {
                                   description: 'nhp del 1',
                                   addresses: [{description: 'nhp dir 1'}]
                               }
                           ]})
    @transaction.commit

  end

  it "From a new transaction: retrieves an aggregate, registers it as dirty, and rollbacks it " do
    tr = UnitOfWork::Transaction.new(Mapper::Sequel)

    company = Company.fetch_by_id(2)
    tr.register_dirty(company)
    company.local_offices[0].description = 'Kilroy 2.0 is everywhere'
    company.local_offices[0].addresses[0].description = 'good evening'
    tr.rollback
    company.local_offices[0].description = 'nhp del 1'
    company.local_offices[0].addresses[0].description = 'nhp dir 1'

  end

  it "From a new transaction: retrieves an aggregate, registers it as dirty and deletes it" do
    tr = UnitOfWork::Transaction.new(Mapper::Sequel)

    company = Company.fetch_by_id(2)
    tr.register_dirty(company)
    tr.register_deleted(company)
    tr.commit
    company = Company.fetch_by_id(2)
    company.should be_nil

    ct = Company.class_variable_get(:'@@attributes')[:local_offices].inner_type
    (ct < BaseEntity).should be_true
    ct.should eq(LocalOffice)

  end

  it 'allows transactions with namespaced entities' do

    module FooModule
      module Models
        class Baz < BaseEntity
          attribute :baz, String
        end
        class Foo < BaseEntity
          children :bars
          attribute :foo, String
          attribute :baz, Baz
        end
        class Bar < BaseEntity
          parent :foo
          attribute :bar, String
          attribute :baz, Baz
        end
      end
    end
    module BarModule
      include FooModule::Models
      Mapper::Sequel.create_tables(Foo, Bar, Baz)

      bazs = $database[:bazs]
      bazs.insert(:baz => 'baz ref 1')

      tr = UnitOfWork::Transaction.new(Mapper::Sequel)

      a_baz = Baz.fetch_by_id(1)
      a_foo = Foo.new({foo:'foo', bars:[{bar:'bar', baz:a_baz}, {bar:'bar2', baz:a_baz}], baz:a_baz})

      EntitySerializer.to_nested_hash(a_foo).should ==({:id=>nil,
                                                       :active=>true,
                                                       :bars=>
                                                           [{:id=>nil,
                                                             :active=>true,
                                                             :bar=>"bar",
                                                             :baz=>{:id=>1, :active=>true, :baz=>"baz ref 1"}},
                                                            {:id=>nil,
                                                             :active=>true,
                                                             :bar=>"bar2",
                                                             :baz=>{:id=>1, :active=>true, :baz=>"baz ref 1"}}],
                                                       :foo=>"foo",
                                                       :baz=>{:id=>1, :active=>true, :baz=>"baz ref 1"}})
      tr.register_new(a_foo)
      tr.commit

      EntitySerializer.to_nested_hash(Foo.fetch_by_id(1)).should ==({:id=>1,
                                                                     :active=>true,
                                                                     :bars=>
                                                                         [{:id=>1,
                                                                           :active=>true,
                                                                           :bar=>"bar",
                                                                           :baz=>{:id=>1, :active=>true, :baz=>"baz ref 1"}},
                                                                          {:id=>2,
                                                                           :active=>true,
                                                                           :bar=>"bar2",
                                                                           :baz=>{:id=>1, :active=>true, :baz=>"baz ref 1"}}],
                                                                     :foo=>"foo",
                                                                     :baz=>{:id=>1, :active=>true, :baz=>"baz ref 1"}})

  # children: delete with [] or nil
  # references: delete with nil
  # always create value references

      a_foo.full_update({:id=>1,
                         :active=>true,
                         :bars=>
                             [{:id=>1,
                               :active=>true,
                               :bar=>"bar",
                               :baz=>a_baz}],
                         :foo=>"foo",
                         :baz=>nil})
      tr.commit

      EntitySerializer.to_nested_hash(Foo.fetch_by_id(1)).should ==({:id=>1,
                                                                     :active=>true,
                                                                     :bars=>
                                                                         [{:id=>1,
                                                                           :active=>true,
                                                                           :bar=>"bar",
                                                                           :baz=>{:id=>1, :active=>true, :baz=>"baz ref 1"}}],
                                                                     :foo=>"foo",
                                                                     :baz=>nil})

      a_foo.full_update({:id=>1,
                         :active=>true,
                         :bars=>[],
                         :foo=>"foo",
                         :baz=>nil})
      tr.commit

      EntitySerializer.to_nested_hash(Foo.fetch_by_id(1)).should ==({:id=>1,
                                                                     :active=>true,
                                                                     :bars=>[],
                                                                     :foo=>"foo",
                                                                     :baz=>nil})

      tr.finalize
    end
  end

end
