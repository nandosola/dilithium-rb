Sequel + Unit Of Work
---------------------
This is an experiment that attempts to apply some DDD/PoEA best practices on top of Sequel's Active Record layer
(blasphemy!):

* Repository
* Mapper

The goal is managing both transactions and concurrency with an ORM-agnostic aproach. Because of that, additional
DDD/PoEA patterns have been implemented:

* Unit Of Work (UoW) with Offline Pessimistic Locking
* A Registry for finding active UoW

This is quite early-stage. Lots of work to do.

### License
Licensed under the [New BSD License](http://opensource.org/licenses/BSD-3-Clause). See LICENSE file for more details.

