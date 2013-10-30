Sequel + Unit Of Work
---------------------
This is an experiment (not yet thread safe!!!) that attempts to apply some PoEA best practices on top of Sequel's DataSet layer.
The goal is being able to manage both transactions and concurrency with an ORM-agnostic aproach. Here you'll find some
interesting patterns:

* Repository
* Mapper
* Unit Of Work (UoW) with concurrency
* A Registry for finding active UoWs

Until a real Data Mapper pattern (in [DataMapper](http://datamapper.org/articles/the_great_refactoring.html) or [ROM](http://rom-rb.org/))
is implemented in Ruby, our domain objects must extend `BaseEntity`.

### Installation
First install the gem via Bundler: `gem 'sequel-uow', :git => 'git://github.com/nandosola/sequel-uow.git'`

### Sample usage
```ruby
require 'sequel-uow'

# ...

String.inflections do |inflect|
  inflect.irregular 'company', 'companies'
  inflect.irregular 'local_office', 'local_offices'
  inflect.irregular 'address', 'addresses'
end

class Company < BaseEntity
  children :local_offices

  attribute :name, String
  attribute :url, String
  attribute :email, String
  attribute :vat_number, String
end

class LocalOffice < BaseEntity
  children  :addresses
  parent :company

  attribute :description, String
end

class Address < BaseEntity
  parent :local_office

  attribute :description, String
  attribute :address, String
  attribute :city, String
  attribute :state, String
  attribute :country, String
  attribute :zip, String
  attribute :phone, String
  attribute :fax, String
  attribute :email, String
  attribute :office, TrueClass, :default => true
  attribute :warehouse, TrueClass, :default => false
end

# ...
transaction = UnitOfWork::Transaction.new(Mapper::Sequel)
company_h = {
        name: 'FooBar, Inc',
        local_offices: [
            {
                description: 'branch1',
                addresses: [{description: 'addr1'}]
            }
        ]
    }

a_company = Company.new(company_h)
transaction.register_new(a_company)

```

`UnitOfWork::Transaction` handles aggregate states and their persistence:

* `register_new`
* `register_clean`
* `register_dirty`
* `register_deleted`
* `commit`
* `rollback`
* `complete`

### TO-DO
* Validate state transitions
* Example/test with complex (multi-object) transaction
* Thread safety
* Serialize state-keeping structures to files
* Optimistic offline concurrency handler
* RDocs & UML docs
* Clearer tests
* ...

### See also

* [datamappify](https://github.com/fredwu/datamappify)
* [Ruby Object Mapper](https://github.com/rom-rb/rom)

### License
Licensed under the [3-clause BSD License](http://opensource.org/licenses/BSD-3-Clause). See LICENSE file for more details.

