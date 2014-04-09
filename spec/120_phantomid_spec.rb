# -*- encoding : utf-8 -*-
require_relative 'spec_base'
require 'lib/model/base_value'
require 'lib/model/phantom_id'

describe 'PhantomIdentifier class' do
  let(:value){
    Class.new(BaseValue) do
      include Dilithium::PhantomIdentifier
      attribute :code, String
      attribute :description, String
      identified_by :code
    end
  }
  let(:entity) {
    Class.new(BaseEntity) do
      attribute :name, String
    end
  }

  it 'cannot be embedded in a BaseEntity' do
    expect{entity.send(:include, Dilithium::PhantomIdentifier)}.to raise_error(ArgumentError)
  end

  it 'adds the _phantomid attribute to a BaseValue' do
    a_value = value.build do |v|
      v.code = 'foo'
      v.description = 'A Foo'
    end

    expect(a_value).to respond_to(:_phantomid)
  end
end

describe 'BaseValue with PhantomIdentifier' do

  before(:all) do
    class Value < BaseValue
      include Dilithium::PhantomIdentifier
      attribute :code, String
      attribute :description, String
      identified_by :code
    end
    SchemaUtils::Sequel.create_tables(Value)
  end
  after(:all) do
    $database.drop_table :values
  end

  describe 'Empty BaseValue' do
    it 'sets _phantomid to nil' do
      empty_value = Value.build
      expect(empty_value._phantomid).to be_nil
    end
  end

  describe 'SchemaUtils::Sequel' do
    it '::create_tables' do
      $database.table_exists?(:values).should be_true
    end
    it '::get_schema' do
      schema = SchemaUtils::Sequel.get_schema(:values)
      expect(schema.key?(:_phantomid)).to be_true
      expect(schema[:_phantomid][:type]).to eq('integer')
    end
  end

  describe 'ValueMapper' do
    it '::insert' do
      a_value = Value.build do |v|
        v.code = 'foo'
        v.description = 'A serious foo'
      end

      Mapper.for(Value).insert(a_value)

      a_value = Value.build do |v|
        v.code = 'bar'
        v.description = 'A merry bar'
      end

      Mapper.for(Value).insert(a_value)

      foo = $database[:values].where(code:'foo').first
      bar = $database[:values].where(code:'bar').first

      expect(foo[:_phantomid]).to eq(1)
      expect(bar[:_phantomid]).to eq(2)
    end
  end

  describe 'ValueRepository' do
    it '#fetch_by_id' do
      a_baz = Value.build do |v|
        v.code = 'baz'
        v.description = 'A sad baz'
      end

      Mapper.for(Value).insert(a_baz)
      res = Repository.for(Value).fetch_by_id('baz')
      expect(a_baz).to eq(res)
    end
    it '#fetch_by_phantomid' do
      bat_value = Value.build do |v|
        v.code = 'bat'
        v.description = 'A bewildered bat'
      end

      Mapper.for(Value).insert(bat_value)
      phantom_id = Repository.for(Value).fetch_by_id('bat')._phantomid
      res = Repository.for(Value).fetch_by_phantomid(phantom_id)
      expect(bat_value).to eq(res)
    end
  end

  describe 'EntitySerializer' do
    describe '::to_hash' do
      it 'should return _phantom_id coerced to Integer' do
        qux_value = Value.build do |v|
          v.code = 'qux'
          v.description = 'A calm qux'
        end

        Mapper.for(Value).insert(qux_value)
        res = Repository.for(Value).fetch_by_id('qux')
        expect(Fixnum === EntitySerializer.to_hash(res)[:_phantomid]).to be_true
      end
      it 'serializes empty BaseValue _phantomid as nil' do
        empty_value = Value.build
        expect(EntitySerializer.to_hash(empty_value)[:_phantomid]).to be_nil
      end
    end
  end

end