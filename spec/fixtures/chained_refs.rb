String.inflections do |inflect|
  inflect.irregular 'foo_ref', 'foo_refs'
  inflect.irregular 'bar_ref', 'bar_refs'
  inflect.irregular 'baz_ref', 'baz_refs'
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