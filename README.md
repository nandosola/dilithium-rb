dilithium-rb
------------
This is an experiment (not yet thread safe!!!) that attempts to apply some PoEA best practices on top of Sequel's DataSet layer.
The goal is being able to manage both transactions and concurrency with an ORM-agnostic aproach. Here you'll find some
interesting patterns:

* Domain model
* Repository
* Mapper
* Unit Of Work (UoW) with concurrency
* A Registry for finding active UoWs
* Offline pessimistic locking (aggregate versioning)

### Caveats
This is a work-in-progress for an internal project, and the public documentation is missing. When milestone 0.1.0 is
achieved, a complete README, plus wiki pages will be uploaded. In the meantime, don't hesitate to ping us. Sorry for the inconvenience!

### See also

* [datamappify](https://github.com/fredwu/datamappify)
* [Ruby Object Mapper](https://github.com/rom-rb/rom)
* [DataMapper](http://datamapper.org/articles/the_great_refactoring.html) as a real data mapper pattern

### License
Licensed under the [3-clause BSD License](http://opensource.org/licenses/BSD-3-Clause). See LICENSE file for more details.

