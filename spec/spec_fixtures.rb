require_relative 'fixtures/simple_entity'
require_relative 'fixtures/aggregate_root'
require_relative 'fixtures/chained_refs'

module SpecFixtures
  def insert_test_users
    items = $database[:users]
    items.insert(:name => 'Alice', :email => 'alice@example.net', :active=>true)
    items.insert(:name => 'Bob', :email => 'bob@example.net', :active=>true)
    items.insert(:name => 'Charly', :email => 'charly@example.net', :active=>true)
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

  def insert_test_refs
    foo = $database[:foo_refs]
    foo.insert(:description => 'foo ref')

    bar = $database[:bar_refs]
    bar.insert(:description => 'bar ref', :foo_ref_id=>1)
    bar.insert(:description => 'bar ref 2', :foo_ref_id=>1)

    baz = $database[:baz_refs]
    baz.insert(:description => 'baz ref', :bar_ref_id=>1)
    baz.insert(:description => 'baz ref 2', :bar_ref_id=>2)

    qux = $database[:quxes]
    qux.insert(:name => 'qux 1')

    bat = $database[:bat_refs]
    bat.insert(:name => 'bat ref', :qux_id=>1)

  end

  def delete_test_refs
    %w(baz_refs bar_refs foo_refs).each do |table|
      $database << "DELETE FROM #{table}" << "DELETE FROM SQLITE_SEQUENCE WHERE NAME = '#{table}'"
    end
  end

  def insert_test_employees_and_depts
    items = $database[:employees]
    items.insert(:name => 'Alice', :active=>true)
    items.insert(:name => 'Bob', :active=>true)
    items.insert(:name => 'Charly', :active=>true)

    items = $database[:departments]
    items.insert(:name => 'Accounting', :active=>true)
    items.insert(:name => 'IT Ops', :active=>true)
    items.insert(:name => 'Sales', :active=>true)
  end

  def delete_test_employees_and_depts
    %w(employees departments).each do |table|
      $database << "DELETE FROM #{table}" << "DELETE FROM SQLITE_SEQUENCE WHERE NAME = '#{table}'"
    end
  end

end
