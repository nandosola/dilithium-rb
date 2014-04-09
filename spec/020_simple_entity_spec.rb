# -*- encoding : utf-8 -*-
require_relative 'spec_base'

describe 'BaseEntity' do

  before(:all) do
    SchemaUtils::Sequel.create_tables(Reference, User)
    insert_test_users
  end

  describe 'infrastructure' do
    it 'is not messed with by another entities' do
      before_attrs = User.attributes

      class AnotherThing < BaseEntity
        attribute :my_thing, String, mandatory:true
      end

      expect(User.attributes).to eq(before_attrs)
    end

    it 'can be fully serialized' do
      a_user = User.fetch_by_id(1)
      test_hash ={
        :id => 1,
        :name => 'Alice',
        :email => 'alice@example.net',
        :tstamp=> DateTime.strptime('2013-09-23T18:42:14+02:00', '%Y-%m-%dT%H:%M:%S%z'),
        :active=>true,
        :reference => nil,
        :refers_to => nil,
        :title => 'Esq.',
        :_version => {id:1, _version:0, _version_created_at:DateTime.parse('2013-09-23T18:42:14+02:00'),
                      _locked_by: nil, _locked_at: nil}
      }

      user_h = EntitySerializer.to_nested_hash(a_user)
      test_hash.each do |k, v|
        expect(user_h[k]).to eq(v)
      end

      expect(a_user.password.to_s).to eq('$2a$10$hqlENYeHZYy9eYHnZ2ONH.5N9qnXV9uzXA/h27XCMq5HBytCLo6bm')
    end
  end

  describe '.build' do
    it 'creates a new entity' do
      a_user = User.build do |u|
        u.name = 'Catbert'
        u.email = 'catbert@example.com'
      end

      expect(a_user).to be_a(User)
      expect(a_user.name).to eq('Catbert')
      expect(a_user.email).to eq('catbert@example.com')
    end

    it 'validates its attributes' do
      User.build do |u|
        u.name = 'Leet'
        expect {u.email = 1337}.to raise_error(ArgumentError)
      end
    end

    it 'validates reference types' do
      User.build do |u|
        u.name = 'PHB'
        expect {u.reference = 'Reference'}.to raise_error(ArgumentError)
      end
    end

    it 'validates invariants' do
      expect {
        User.build do |u|
          u.email = 'ratbert@example.com'
        end
      }.to raise_error(DomainObjectExceptions::ValidationFailed)
    end
  end

  describe 'accessors and mutators' do
    it 'has the proper methods' do
      a_user = User.build { |u| u.name = 'Wally' }

      expect(a_user).to be_a(User)
      expect(a_user).to respond_to(:id)
      expect(a_user).to respond_to(:id=)
      expect(a_user).to respond_to(:name)
      expect(a_user).to respond_to(:name=)
      expect(a_user).to respond_to(:email)
      expect(a_user).to respond_to(:email=)
      expect(a_user.instance_variables.include?(:'@my_thing')).to be_false
      expect(a_user).to_not respond_to(:my_thing)
      expect(a_user).to_not respond_to(:my_thing=)

    end

    it 'validates its attributes' do
      new_user = User.build { |u| u.name = 'Dilbert '}
      my_reference = Reference.build { |r| r.name ='test' }

      expect(my_reference.name).to eq('test')
      expect(new_user.reference).to be_nil
      expect {new_user.reference = 'foo'}.to raise_error(ArgumentError)
      expect {new_user.reference = my_reference}.to_not raise_error
      expect {new_user.email = 42}.to raise_error(ArgumentError)
      expect {new_user.name = 1337}.to raise_error(ArgumentError)
    end

  end

  describe 'finders' do
    describe '#fetch_by_id' do
      it 'retrieves an entity given its ID' do
        a_user = User.fetch_by_id(1)
        expect(a_user.class).to eq(User)
        expect(a_user.name).to eq('Alice')
      end

      it 'raises an error if the ID doesn\'t exist' do
        expect {User.fetch_by_id(42)}.to raise_error { |error|
          expect(error).to be_a PersistenceExceptions::NotFound
          expect(error.id).to eq({id: 42})
          expect(error.type).to eq(User)
        }
      end
    end

    describe '#fetch_all' do
      it 'retrieves all entities of a given type' do
        users = $database[:users].all

        all_users = User.fetch_all

        all_users.each_with_index do |u, i|
          expect(u).to be_a(User)
          expect(u.name).to eq(users[i][:name])
          expect(u.email).to eq(users[i][:email])
          expect(u.title).to eq(users[i][:title])
        end
      end
    end

    describe 'custom finders' do
      it 'fetches by arbitrary attributes' do
        expect(User.fetch_by_email('bob@example.net').first.name).to eq('Bob')
        expect(User.fetch_by_name('Charly').first.id).to eq(3)
      end
    end


    describe 'references' do
      it 'fetches references' do
        duke = User.fetch_by_email('duke@example.net').first
        expect(duke.reference).to be_a(Association::ImmutableEntityReference)
        expect(duke.reference._type).to eq(Reference)
        expect(duke.reference.id).to eq(1)
        duke.reference.resolve
        expect(duke.reference.resolved_entity.name).to eq('Duke ref')

        expect(duke.refers_to).to be_a(Association::ImmutableEntityReference)
        expect(duke.refers_to._type).to eq(Reference)
        expect(duke.refers_to.id).to eq(2)
      end

      it 'has not parent reference' do
        user = User.fetch_by_id(1)
        expect(user.class.parent_reference).to eq(nil)
      end
    end
  end

  describe '.full_update' do
    it 'can be fully updated' do
      user = User.build do |u|
        u.id = 42
        u.name = 'PHB'
        u.email = 'phb@example.net'
      end

      user.full_update({id:42, :name => 'Dogbert', :email => 'dogbert@example.net'})
      expect(user.id).to eq(42)
      expect(user.name).to eq('Dogbert')
      expect(user.email).to eq('dogbert@example.net')

      user.full_update({id:42, :name => 'Catbert'})
      expect(user.id).to eq(42)
      expect(user.name).to eq('Catbert')
      expect(user.email).to be_nil

      user.full_update({id:42, :name => 'Ratbert', :email => nil})
      expect(user.id).to eq(42)
      expect(user.id).to eq(42)
      expect(user.name).to eq('Ratbert')
      expect(user.email).to be_nil

      expect {user.full_update({:email => 'ratbert@example.net'}) }.to raise_error(ArgumentError)

    end
  end

  describe '.immutable' do
    let(:a_user) { User.fetch_by_email('zaphod@example.net').first }
    subject(:an_immutable_user) { a_user.immutable }

    describe 'returns an immutable copy of itself' do
      it {should be_a(User::Immutable)}      
    end
    
    describe 'has the same accessors as the original' do
      it { should respond_to(:id)}
      it { should respond_to(:name)}
      it { should respond_to(:email)}
    end

    it 'copies over the attribute values from the original' do
      expect(an_immutable_user.id).to eq(a_user.id)
      expect(an_immutable_user.name).to eq(a_user.name)
      expect(an_immutable_user.email).to eq(a_user.email)
    end

    describe 'doesn\'t have any mutators' do
      it { should_not respond_to(:id=)}
      it { should_not respond_to(:name=)}
      it { should_not respond_to(:email=)}
    end

    describe 'doesn\'t have any references' do
      it { should_not respond_to(:reference)}
      it { should_not respond_to(:reference=)}
      it { should_not respond_to(:refers_to)}
      it { should_not respond_to(:refers_to=)}
    end
  end

  after(:all) do
    %i(users references _versions).each do |t|
      $database.drop_table t
      $database << "DELETE FROM SQLITE_SEQUENCE WHERE NAME = '#{t}'"
    end
  end
end

