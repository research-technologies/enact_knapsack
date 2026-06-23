# frozen_string_literal: true

require 'rails_helper'

# The `:contributors` linked_record source's inline create proc (registered in
# config/initializers/enact_linked_records.rb) maps the profile's create_fields
# to an Enact::Contributor: `affiliations` is a repeatable scalar (an Array of
# strings) and `name_identifiers` a repeatable group (an Array of {value, scheme}
# hashes), each feeding the model's multi-valued writers. Exercised through the
# generic resolver, as the create endpoint does.
RSpec.describe 'Enact :contributors linked_record create proc' do
  subject(:created) { Hyrax::CompoundLinkedRecordResolver.create(:contributors, attrs) }

  context 'with the full inline create_fields' do
    let(:attrs) do
      { display_name: 'Grace Hopper', orcid: 'https://orcid.org/0000-0001-2345-6789',
        agent_type: 'organization',
        affiliations: ['US Navy', 'Vassar College'],
        name_identifiers: [{ value: '0000000121032683', scheme: 'ISNI' },
                           { value: 'https://ror.org/02mhbdp94', scheme: 'ROR' }] }
    end

    it 'creates a persisted contributor with every field mapped' do
      expect(created).to be_persisted
      expect(created.display_name).to eq('Grace Hopper')
      expect(created.orcid).to eq('https://orcid.org/0000-0001-2345-6789')
      expect(created.agent_type).to eq('organization')
      expect(created.affiliations).to eq(['US Navy', 'Vassar College'])
      expect(created.name_identifiers).to eq(
        [{ 'value' => '0000000121032683', 'scheme' => 'ISNI' },
         { 'value' => 'https://ror.org/02mhbdp94', 'scheme' => 'ROR' }]
      )
    end
  end

  context 'with only the required field' do
    let(:attrs) { { display_name: 'Ada Lovelace' } }

    it 'creates a contributor and leaves the optional fields blank' do
      expect(created).to be_persisted
      expect(created.affiliations).to eq([])
      expect(created.name_identifiers).to eq([])
    end
  end
end
