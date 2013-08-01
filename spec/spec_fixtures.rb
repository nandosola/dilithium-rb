require_relative 'fixtures/user'

module SpecFixtures
  def insert_test_users
    items = DB[:users]
    items.insert(:name => 'Alice', :email => 'alice@example.net')
    items.insert(:name => 'Bob', :email => 'bob@example.net')
    items.insert(:name => 'Charly', :email => 'charly@example.net') 
  end
  def delete_test_users
    DB << "DELETE FROM users" << "DELETE FROM SQLITE_SEQUENCE WHERE NAME = 'users'"
  end
end
