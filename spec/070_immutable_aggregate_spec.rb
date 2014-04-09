# -*- encoding : utf-8 -*-
require_relative 'spec_base'

describe 'An aggregate model' do
  it 'should create an immutable copy of itself' do
    a_company = Company.build do |c|
      c.name = 'Abstra.cc S.A'
      c.make_local_office do |l|
        l.description = 'branch1'
        l.make_address { |a| a.description = 'addr1' }
      end
    end

    immutable = a_company.immutable
    immutable.should be_a(Company::Immutable)
    immutable.id.should eq(a_company.id)
    immutable.name.should eq(a_company.name)
    immutable.respond_to?(:local_offices).should be_false
  end
end
