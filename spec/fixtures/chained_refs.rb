# -*- encoding : utf-8 -*-
String.inflections do |inflect|
  inflect.irregular 'foo_ref', 'foo_refs'
  inflect.irregular 'bar_ref', 'bar_refs'
  inflect.irregular 'baz_ref', 'baz_refs'
  inflect.irregular 'bat_ref', 'bat_refs'
  inflect.irregular 'qux', 'quxes'
  inflect.irregular 'my_entity', 'my_entities'
end

class FooRef < BaseEntity
  attribute :description, String
end
class BarRef < BaseEntity
  attribute :description, String
  reference :foo_ref, FooRef
end
class BazRef < BaseEntity
  attribute :description, String
  reference :bar_ref, BarRef
end

class Qux < BaseEntity
  attribute :name, String
end

class BatRef < BaseEntity
  attribute :name, String
  reference :qux, Qux
end

class MyEntity < BaseEntity
  attribute :description, String
  reference :qux, Qux
  reference :baz_ref, BazRef
  reference :bat_ref, BatRef
end
