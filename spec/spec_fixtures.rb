require_relative 'fixtures/simple_entity'
require_relative 'fixtures/aggregate_root'
require_relative 'fixtures/chained_refs'

module SpecFixtures
  def insert_test_users
    tstamp = '2013-09-23T18:42:14+02:00'
    password = '$2a$10$hqlENYeHZYy9eYHnZ2ONH.5N9qnXV9uzXA/h27XCMq5HBytCLo6bm'  # 'secret'

    versions = $database[:_versions]
    versions.insert(:id => 1, :_version => 0, :_version_created_at => tstamp)
    versions.insert(:id => 2, :_version => 0, :_version_created_at => tstamp)
    versions.insert(:id => 3, :_version => 0, :_version_created_at => tstamp)
    versions.insert(:id => 4, :_version => 0, :_version_created_at => tstamp)
    versions.insert(:id => 5, :_version => 0, :_version_created_at => tstamp)
    versions.insert(:id => 6, :_version => 0, :_version_created_at => tstamp)
    versions.insert(:id => 7, :_version => 0, :_version_created_at => tstamp)

    references = $database[:references]
    references.insert(:name => 'Duke ref', :active=>true, :_version_id=>4)
    references.insert(:name => 'Foo ref', :_version_id=>5)

    users = $database[:users]
    users.insert(:name => 'Alice', :email => 'alice@example.net', :tstamp=> tstamp, :password=>password, :active=>true, :_version_id=>1)
    users.insert(:name => 'Bob', :email => 'bob@example.net', :tstamp=> tstamp, :password=>password,  :active=>true, :_version_id=>2)
    users.insert(:name => 'Charly', :email => 'charly@example.net', :tstamp=> tstamp, :password=>password,  :active=>true, :_version_id=>3)
    users.insert(:name => 'Duke', :email => 'duke@example.net', :reference_id => 1, :refers_to_id => 2, :active=>true, :_version_id=>6)
    users.insert(:name => 'Zaphod', :email => 'zaphod@example.net', :reference_id => 1, :refers_to_id => 2, :active=>true, :_version_id=>7)
  end

  def insert_test_refs
    tstamp = '2013-09-23T18:42:14+02:00'

    versions = $database[:_versions]
    versions.insert(:id => 1, :_version => 0, :_version_created_at => tstamp)
    versions.insert(:id => 2, :_version => 0, :_version_created_at => tstamp)
    versions.insert(:id => 3, :_version => 0, :_version_created_at => tstamp)
    versions.insert(:id => 4, :_version => 0, :_version_created_at => tstamp)
    versions.insert(:id => 5, :_version => 0, :_version_created_at => tstamp)
    versions.insert(:id => 6, :_version => 0, :_version_created_at => tstamp)
    versions.insert(:id => 7, :_version => 0, :_version_created_at => tstamp)

    foo = $database[:foo_refs]
    foo.insert(:description => 'foo ref', :_version_id=>1)

    bar = $database[:bar_refs]
    bar.insert(:description => 'bar ref', :foo_ref_id=>1, :_version_id=>2)
    bar.insert(:description => 'bar ref 2', :foo_ref_id=>1, :_version_id=>3)

    baz = $database[:baz_refs]
    baz.insert(:description => 'baz ref', :bar_ref_id=>1, :_version_id=>4)
    baz.insert(:description => 'baz ref 2', :bar_ref_id=>2, :_version_id=>5)

    qux = $database[:quxes]
    qux.insert(:name => 'qux 1', :_version_id=>6)

    bat = $database[:bat_refs]
    bat.insert(:name => 'bat ref', :qux_id=>1, :_version_id=>7)
  end

  def insert_test_employees_depts_and_buildings

    tstamp = '2013-09-23T18:42:14+02:00'

    versions = $database[:_versions]
    versions.insert(:id => 1, :_version => 0, :_version_created_at => tstamp)
    versions.insert(:id => 2, :_version => 0, :_version_created_at => tstamp)
    versions.insert(:id => 3, :_version => 0, :_version_created_at => tstamp)
    versions.insert(:id => 4, :_version => 0, :_version_created_at => tstamp)
    versions.insert(:id => 5, :_version => 0, :_version_created_at => tstamp)
    versions.insert(:id => 6, :_version => 0, :_version_created_at => tstamp)
    versions.insert(:id => 7, :_version => 0, :_version_created_at => tstamp)
    versions.insert(:id => 8, :_version => 0, :_version_created_at => tstamp)
    versions.insert(:id => 9, :_version => 0, :_version_created_at => tstamp)
    versions.insert(:id => 10, :_version => 0, :_version_created_at => tstamp)

    items = $database[:employees]
    items.insert(:name => 'Alice', :active=>true, :_version_id=>1)
    items.insert(:name => 'Bob', :active=>true, :_version_id=>2)
    items.insert(:name => 'Charly', :active=>true, :_version_id=>3)

    items = $database[:departments]
    items.insert(:name => 'Accounting', :active=>true, :_version_id=>4)
    items.insert(:name => 'IT Ops', :active=>true, :_version_id=>5)
    items.insert(:name => 'Sales', :active=>true, :_version_id=>6)
    items.insert(:name => 'Marketing', :active=>true, :_version_id=>7)
    items.insert(:name => 'Administration', :active=>true, :_version_id=>8)

    items = $database[:buildings]
    items.insert(:name => 'Main', :active=>true, :_version_id=>9)
    items.insert(:name => 'Conference Center', :active=>true, :_version_id=>10)
  end

end
