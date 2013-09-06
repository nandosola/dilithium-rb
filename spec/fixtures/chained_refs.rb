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
  attribute :foo_ref, FooRef
end
class BazRef < BaseEntity
  attribute :description, String
  attribute :bar_ref, BarRef
end

class Qux < BaseEntity
  attribute :name, String
end

class BatRef < BaseEntity
  attribute :name, String
  attribute :qux, Qux
end

class MyEntity < BaseEntity
  attribute :description, String
  attribute :qux, Qux
  attribute :baz_ref, BazRef
  attribute :bat_ref, BatRef
end