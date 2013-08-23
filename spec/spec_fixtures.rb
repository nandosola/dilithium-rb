require_relative 'fixtures/simple_entity'

module SpecFixtures
  def insert_test_users
    items = $database[:users]
    items.insert(:name => 'Alice', :email => 'alice@example.net')
    items.insert(:name => 'Bob', :email => 'bob@example.net')
    items.insert(:name => 'Charly', :email => 'charly@example.net') 
  end
  def delete_test_users
    $database << "DELETE FROM users" << "DELETE FROM SQLITE_SEQUENCE WHERE NAME = 'users'"
  end
end
