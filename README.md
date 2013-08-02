Sequel + Unit Of Work
---------------------
This is an experiment (not yet thread safe!!!) that attempts to apply some PoEA best practices on top of Sequel's Active Record layer
(blasphemy!). The goal is being able to manage both transactions and concurrency with an ORM-agnostic aproach. Here you'll find some
interesting patterns:

* Repository
* Mapper
* Unit Of Work (UoW) with Offline Pessimistic Locking
* A Registry for finding active UoWs

### Installation
First install the gem via Bundler: `gem 'sequel-uow', :git => 'git://github.com/nandosola/sequel-uow.git'`

### Sample usage
Until a [real Data Mapper pattern](http://datamapper.org/articles/the_great_refactoring.html)
is implemented in Rubby, our domain objects must extend `Sequel::Model`.

The gem includes a `FinderService` facade to be used by our domain objects so that their active transactions can be found:

```ruby
require 'sequel-uow'

# ...

moduleUnitOfWork::TransactionRegistry
# ...
module FinderService
  module ClassMethods
    def self.extended(base_class)
      base_class.instance_eval {
        def fetch_from_transaction(uuid, obj_id)
          tr = Registry.instance[uuid.to_sym]
          (tr.nil?) ? nil : tr.fetch_object_by_id(self, obj_id)
        end
      }
    end
  end
  module InstanceMethods
    def transactions
      Registry.instance.find_transactions(self)
    end
  end
end
end

# ...

class User < Sequel::Model
  extend UnitOfWork::TransactionRegistry::FinderService::ClassMethods
  include UnitOfWork::TransactionRegistry::FinderService::InstanceMethods

  # specific repository methods:
  extend Repository::Sequel::User

  # Business logic
  # ...
end
```

`UnitOfWork::Transaction` instances handle the states and their persistence:

* `register_new`
* `register_clean`
* `register_dirty`
* `register_deleted`
* `commit`
* `rollback`
* `complete`


For a simple Sinatra, CRUD-like web application:
```ruby
post '/activities/user/new' do

  transaction = UnitOfWork::Transaction.new()
  a_user = User.new()
  transaction.register_new(a_user)
  [201, "{id: #{transaction.uuid}}"]  # commands could be sent as hypermedia
end

# ...

# update command
put '/transactions/:uuid/user/:id/update' do

  parsed_body = JsonParserService.parse(body)  # To be implemented by the developer

  result = User.fetch_from_transaction(:uuid, :id)
    # returns a TransactionRegistry::Registry::SearchResult or nil

  user = result.object
  transaction = result.transaction

  user.validate(parsed_body)
  user.set_all(parsed_body)
  transaction.commit
  transaction.complete
  200
end
```

### TO-DO
* Validate state transitions
* Process URI CRUD commands as a group of `Transaction` operations
* Aggregate handling
* Example/test with complex (multi-object) transaction
* Thread safety
* Serialize state-keeping structures to files
* Optimistic offline concurrency handler
* RDocs & UML docs
* ...

### License
Licensed under the [New BSD License](http://opensource.org/licenses/BSD-3-Clause). See LICENSE file for more details.

