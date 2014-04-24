# -*- encoding : utf-8 -*-
require_relative 'spec_base'

describe 'A Transaction handling an Aggregate Entity' do
  before(:all) do
    SchemaUtils::Sequel.create_tables(Company, LocalOffice, Address, Contractor)
    class UnitOfWork::Transaction
      # exposed ONLY for testing purposes
      def tracked_objects
        @object_tracker
      end
    end
  end

  before(:each) do
    @transaction = UnitOfWork::Transaction.new(EntityMapper::Sequel)
  end

  after(:each) do
    @transaction.rollback unless @transaction.committed
    @transaction.finalize
  end

  let(:test_payload){
    Class.new do
      include BaseEntityPayload
      def initialize(in_h)
        @payload = in_h
      end
      def content
        @payload
      end
    end
  }

  it 'creates a new Aggregate without children' do
    a_company = Company.build { |c| c.name = 'Abstra.cc S.A'}
    a_company.name.should eq('Abstra.cc S.A')
  end

  it 'creates a new Aggregate with children' do
    a_company = Company.build do |c|
      c.name = 'Abstra.cc, S.A.'
      c.make_local_office do |l|
        l.description = 'branch1'
        l.make_address { |a| a.description = 'addr1' }
        l.make_address { |a| a.description = 'addr2' }
      end
    end

    expect(a_company.local_offices.size).to eq(1)

    office = a_company.local_offices.first
    expect(office.company).to eq(a_company)

    expect(office.addresses.size).to eq(2)
    office.addresses.each do |a|
      expect(a.local_office).to eq(office)
    end
  end

  it 'creates a new Aggregate in the database and retrieves it correctly' do
    a_company = Company.build do |c|
      c.name = 'Abstra.cc S.A'
      c.make_local_office do |l|
        l.description = 'branch1'
        l.make_address { |a| a.description = 'addr1' }
      end
    end
    @transaction.register_new(a_company)

    a_company.make_local_office do |l|
      l.description = 'branch2'
      l.make_address { |a| a.description = 'addr2.1' }
    end

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

    abstra = Company.fetch_by_id(1)

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

  it 'creates a new aggregate, retrieves it and performs updates' do
    b_company = Company.build do |c|
      c.name = 'Smarty Pants, Inc.'
      c.make_local_office do |l|
        l.description = 'foo del 1'
        l.make_address { |a| a.description = 'foo dir 1' }
        l.make_address { |a| a.description = 'foo dir 2' }
      end
    end

    @transaction.register_new(b_company)

    @transaction.commit

    smarty_pants =  Company.fetch_by_id(2)

    smarty_pants.name.should eq('Smarty Pants, Inc.')
    smarty_pants.id.should eq(2)
    smarty_pants._version._version.should eq(0)

    smarty_pants.local_offices.size.should eq(1)

    smarty_pants.local_offices[0].description.should eq('foo del 1')
    smarty_pants.local_offices[0].addresses.size.should eq(2)
    smarty_pants.local_offices[0].addresses[0].description.should eq('foo dir 1')
    smarty_pants.local_offices[0].addresses[1].description.should eq('foo dir 2')
    Company.fetch_all.size.should eq(2)

    payload = test_payload.new({id: 2,
                           url: 'http://example.net',
                           name: 'New Horizon Partners, Inc.',
                           local_offices: [
                             {
                               description: 'nhp del 1',
                               addresses: [{description: 'nhp dir 1'}]
                             }
                           ]})
    BaseEntityMassUpdater.new(b_company, payload).update!

    @transaction.commit

    new_horizon = Company.fetch_by_id(2)
    new_horizon.name.should eq('New Horizon Partners, Inc.')
    new_horizon.url.should eq('http://example.net')
    new_horizon.id.should eq(2)
    new_horizon._version._version.should eq(1)

    new_horizon.local_offices.size.should eq(1)

    new_horizon.local_offices[0].description.should eq('nhp del 1')
    new_horizon.local_offices[0].addresses.size.should eq(1)
    new_horizon.local_offices[0].addresses[0].description.should eq('nhp dir 1')


    payload = test_payload.new({id: 2,
                           url: 'http://example.net',
                           name: 'New Horizon Partners, Inc.',
                           local_offices: [
                             {
                               description: 'nhp del 1',
                               addresses: []
                             }
                           ]})
    BaseEntityMassUpdater.new(b_company, payload).update!

    @transaction.commit

    new_horizon = Company.fetch_by_id(2)
    new_horizon._version._version.should eq(2)

    new_horizon.local_offices.size.should eq(1)
    new_horizon.local_offices[0].addresses.size.should eq(0)

    payload = test_payload.new({id: 2,
                           url: 'http://example.net',
                           name: 'New Horizon Partners, Inc.',
                           local_offices: []})
    BaseEntityMassUpdater.new(b_company, payload).update!

    @transaction.commit

    new_horizon = Company.fetch_by_id(2)
    new_horizon._version._version.should eq(3)
    new_horizon.local_offices.size.should eq(0)

    payload = test_payload.new({id: 2,
                           url: 'http://example.net',
                           name: 'New Horizon Partners, Inc.',
                           local_offices: [
                             {
                               description: 'nhp del 1',
                               addresses: [{description: 'nhp dir 1'}]
                             }
                           ]})
    BaseEntityMassUpdater.new(b_company, payload).update!

    @transaction.commit

    new_horizon = Company.fetch_by_id(2)
    new_horizon._version._version.should eq(4)
    new_horizon.local_offices.size.should eq(1)

    payload = test_payload.new({id: 2,
                           url: 'http://example.net',
                           name: 'New Horizon Partners, Inc.',
                           local_offices: nil})
    BaseEntityMassUpdater.new(b_company, payload).update!

    @transaction.commit

    new_horizon = Company.fetch_by_id(2)
    new_horizon._version._version.should eq(5)
    new_horizon.local_offices.size.should eq(0)

    payload = test_payload.new({id: 2,
                           url: 'http://example.net',
                           name: 'New Horizon Partners, Inc.',
                           local_offices: [
                             {
                               description: 'nhp del 1',
                               addresses: [{description: 'nhp dir 1'}]
                             }
                           ]})
    BaseEntityMassUpdater.new(b_company, payload).update!

    @transaction.commit

    new_horizon = Company.fetch_by_id(2)
    new_horizon._version._version.should eq(6)

  end

  it 'From a new transaction: retrieves an aggregate, registers it as dirty, and rollbacks it ' do
    tr = UnitOfWork::Transaction.new(EntityMapper::Sequel)

    company = Company.fetch_by_id(2)
    tr.register_dirty(company)
    company.local_offices[0].description = 'Kilroy 2.0 is everywhere'
    company.local_offices[0].addresses[0].description = 'good evening'
    tr.rollback
    company.local_offices[0].description = 'nhp del 1'
    company.local_offices[0].addresses[0].description = 'nhp dir 1'

  end

  it 'From a new transaction: retrieves an aggregate, registers it as dirty and deletes it' do
    tr = UnitOfWork::Transaction.new(EntityMapper::Sequel)

    company = Company.fetch_by_id(2)
    tr.register_dirty(company)
    tr.register_deleted(company)
    tr.commit
    company = Company.fetch_by_id(2)
    company.active.should be_false

    ct = Company.attribute_descriptors[:local_offices].inner_type
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
          reference :baz, Baz
        end
        class Bar < BaseEntity
          parent :foo
          attribute :bar, String
          reference :baz, Baz
        end
      end
    end
    module BarModule
      include FooModule::Models
      SchemaUtils::Sequel.create_tables(Foo, Bar, Baz)
      test_payload =
        Class.new do
          include BaseEntityPayload
          def initialize(in_h)
            @payload = in_h
          end
          def content
            @payload
          end
        end

      versions = $database[:_versions]
      v_id = versions.insert(:_version => 0, :_version_created_at => DateTime.parse('2013-09-23T18:42:14+02:00'))
      bazs = $database[:bazs]
      bazs.insert(:baz => 'baz ref 1', :_version_id => v_id)

      tr = UnitOfWork::Transaction.new(EntityMapper::Sequel)

      a_baz = Baz.fetch_by_id(1)
      a_foo = Foo.build do |f|

        f.foo ='foo'
        f.baz = a_baz

        f.make_bar do |b|
          b.bar = 'bar'
          b.baz = a_baz
        end

        f.make_bar do |b|
          b.bar = 'bar2'
          b.baz = a_baz
        end
      end

      baz_ref = Association::ImmutableEntityReference.create(a_baz)
      kk = EntitySerializer.to_nested_hash(a_foo)

      kk.should ==({:id=>nil,
                                                        :active=>true,
                                                        :_version=>{:id=>nil,
                                                                    :_version=>0,
                                                                    :_version_created_at=>a_foo._version._version_created_at,
                                                                    :_locked_by=>nil, :_locked_at=>nil},
                                                        :bars=>
                                                          [{:id=>nil,
                                                            :active=>true,
                                                            :_version=>{:id=>nil,
                                                                        :_version=>0,
                                                                        :_version_created_at=>a_foo.bars[0]._version._version_created_at,
                                                                        :_locked_by=>nil, :_locked_at=>nil},
                                                            :bar=>"bar",
                                                            :baz=>baz_ref
                                                           },
                                                           {:id=>nil,
                                                            :active=>true,
                                                            :_version=>{:id=>nil,
                                                                        :_version=>0,
                                                                        :_version_created_at=>a_foo.bars[1]._version._version_created_at,
                                                                        :_locked_by=>nil, :_locked_at=>nil},
                                                            :bar=>"bar2",
                                                            :baz=>baz_ref
                                                           }],
                                                        :foo=>"foo",
                                                        :baz=>baz_ref
      })



      tr.register_new(a_foo)
      tr.register_clean(a_baz)
      tr.commit


      persisted_foo = Foo.fetch_by_id(1)
      EntitySerializer.to_nested_hash(persisted_foo).should==({:id=>1,
                                                               :active=>true,
                                                               :bars=>
                                                                 [{:id=>1,
                                                                   :active=>true,
                                                                   :bar=>"bar",
                                                                   :baz=>baz_ref,
                                                                   :_version=>{:id=>4,
                                                                               :_version=>0,
                                                                               :_version_created_at=>a_foo.bars[0]._version._version_created_at,
                                                                               :_locked_by=>nil, :_locked_at=>nil}
                                                                  },
                                                                  {:id=>2,
                                                                   :active=>true,
                                                                   :bar=>"bar2",
                                                                   :baz=>baz_ref,
                                                                   :_version=>{:id=>4,
                                                                               :_version=>0,
                                                                               :_version_created_at=>a_foo.bars[1]._version._version_created_at,
                                                                               :_locked_by=>nil, :_locked_at=>nil}
                                                                  }],
                                                               :foo=>"foo",
                                                               :baz=>baz_ref,
                                                               :_version=>{:id=>4,
                                                                           :_version=>0,
                                                                           :_version_created_at=>a_foo._version._version_created_at,
                                                                           :_locked_by=>nil, :_locked_at=>nil}})

      # children: delete with [] or nil
      # references: delete with nil
      # always create value references

      payload = test_payload.new({:id=>1,
                         :active=>true,
                         :bars=>
                           [{:id=>1,
                             :active=>true,
                             :bar=>"bar",
                             :baz=>a_baz}],
                         :foo=>"foo",
                         :baz=>nil})
      BaseEntityMassUpdater.new(a_foo, payload).update!

      tr.commit

      updated_foo = Foo.fetch_by_id(1)
      EntitySerializer.to_nested_hash(updated_foo).should ==( {:id=>1,
                                                               :active=>true,
                                                               :bars=>
                                                                 [{:id=>1,
                                                                   :active=>true,
                                                                   :bar=>"bar",
                                                                   :baz=>baz_ref,
                                                                   :_version=>{:id=>4, :_version=>1,
                                                                               :_version_created_at=>updated_foo._version._version_created_at,
                                                                               :_locked_by=>nil, :_locked_at=>nil}}],
                                                               :foo=>"foo",
                                                               :baz=>nil,
                                                               :_version=>{:id=>4, :_version=>1,
                                                                           :_version_created_at=>updated_foo._version._version_created_at,
                                                                           :_locked_by=>nil, :_locked_at=>nil}})

      payload = test_payload.new({:id=>1,
                         :active=>true,
                         :bars=>[],
                         :foo=>"foo",
                         :baz=>nil})
      BaseEntityMassUpdater.new(a_foo, payload).update!

      tr.commit

      updated_foo = Foo.fetch_by_id(1)
      EntitySerializer.to_nested_hash(updated_foo).should ==( {:id=>1,
                                                               :active=>true,
                                                               :_version=>{:id=>4, :_version=>2,
                                                                           :_version_created_at=>updated_foo._version._version_created_at,
                                                                           :_locked_by=>nil, :_locked_at=>nil},
                                                               :bars=>[],
                                                               :foo=>"foo",
                                                               :baz=>nil})

      tr.finalize
    end
  end

  it 'Correctly handles references between different roots' do
    a_company = Company.build do |c|
      c.name = 'Gallifreyan Sonic Widgets, Inc.'
      c.make_local_office do |l|
        l.description = 'Head Office'
        l.make_address { |a| a.description = 'Gallifrey'}
      end
    end

    @transaction.register_new(a_company)
    @transaction.commit

    a_company = Company.fetch_by_id(a_company.id)
    office = a_company.local_offices[0]

    contractor = Contractor.build do |c|
      c.local_office = office
      c.name = 'Romana'
      c.email = 'romana@timelords.com'
    end

    @transaction.register_new(contractor)
    @transaction.commit

    romana = Contractor.fetch_by_id(contractor.id)

    romana.local_office.id.should eq(office.id)
    romana.name.should eq('Romana')
    romana.local_office._type.should eq(LocalOffice)
  end

  it 'Correctly persists an intermediate root' do
    name = 'TARDIS Console Repair, Inc.'

    a_company = Company.build do |c|
      c.name = name
      c.make_local_office do |l|
        l.description = 'HQ'
        l.make_address { |a| a.description = 'Warehouse District'}
      end
    end

    @transaction.register_new(a_company)
    @transaction.commit
    @transaction.register_clean(a_company)

    a_company = Company.fetch_by_name(name)[0]
    office = a_company.local_offices[0]
    @transaction.register_dirty(office)

    office.description = 'Headquarters'
    office.make_address do |a|
      a.description = 'Timelord Palace'
    end
    @transaction.commit

    a_company = Company.fetch_by_name(name)[0]
    office = a_company.local_offices.select{|o| o.description == "HQ"}
    office.should be_empty

    office = a_company.local_offices.select{|o| o.description == "Headquarters"}[0]
    office.addresses.length.should == 2
    office.addresses[0].description.should == 'Warehouse District'
    office.addresses[1].description.should == 'Timelord Palace'
  end

  after(:all) do
    [:contractors, :addresses, :local_offices, :companies, :bars, :bazs, :foos, :_versions].each do |t|
      $database.drop_table t
      $database << "DELETE FROM SQLITE_SEQUENCE WHERE NAME = '#{t}'"
    end
  end
end
