require_relative 'fixtures/simple_entity'
require_relative 'fixtures/aggregate_root'

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

  def insert_test_companies
    items = $database[:companies]
    items.insert({:name => 'Company A', :vat_number => '1111',
                 :local_offices => [
                   {:description => 'Office A1',
                     :addresses => [
                       {:description => 'Address A11'},
                       {:description => 'Address A12'}]},
                    {:description => 'Office A2',
                      :addresses => [
                        {:description => 'Address A21'},
                        {:description => 'Address A22'}]}]})
    items.insert({:name => 'Company B', :vat_number => '2222',
                 :local_offices => [
                   {:description => 'Office B1',
                     :addresses => [
                       {:description => 'Address B11'},
                       {:description => 'Address B12'}]},
                    {:description => 'Office B2',
                      :addresses => [
                        {:description => 'Address B21'},
                        {:description => 'Address B22'}]}]})
    items.insert({:name => 'Company C', :vat_number => '3333',
                 :local_offices => [
                   {:description => 'Office C1',
                     :addresses => [
                       {:description => 'Address C11'},
                       {:description => 'Address C12'}]},
                    {:description => 'Office C2',
                      :addresses => [
                        {:description => 'Address C21'},
                        {:description => 'Address C22'}]}]})
    items.insert({:name => 'Company D', :vat_number => '4444',
                 :local_offices => [
                   {:description => 'Office D1',
                     :addresses => [
                       {:description => 'Address D11'},
                       {:description => 'Address D12'}]},
                    {:description => 'Office D2',
                      :addresses => [
                        {:description => 'Address D21'},
                        {:description => 'Address D22'}]}]})
  end
end
