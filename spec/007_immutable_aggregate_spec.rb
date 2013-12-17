require_relative 'spec_base'

describe 'An aggregate entity' do
  it 'should create an immutable copy of itself' do
    company1_h = {
      name: 'Abstra.cc S.A',
      local_offices: [
        {
          description: 'branch1',
          addresses: [{description: 'addr1'}]
        }
      ]
    }

    a_company = Company.new(company1_h)
    immutable = a_company.immutable
    immutable.should be_a(Company::Immutable)
    immutable.id.should eq(a_company.id)
    immutable.name.should eq(a_company.name)
    immutable.respond_to?(:local_offices).should be_false
  end
end