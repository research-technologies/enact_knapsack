# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Enact::Contributor do
  it 'persists with only a display_name (no email/login required)' do
    contributor = described_class.create!(display_name: 'Ada Lovelace')
    expect(contributor).to be_persisted
    expect(contributor.reload.display_name).to eq('Ada Lovelace')
  end

  it 'requires a display_name' do
    contributor = described_class.new
    expect(contributor).not_to be_valid
    expect(contributor.errors[:display_name]).to be_present
  end

  describe 'agent_type' do
    it 'defaults to person' do
      expect(described_class.new.agent_type).to eq('person')
      expect(described_class.new).to be_person
    end

    it 'supports organization' do
      org = described_class.create!(display_name: 'Acme Lab', agent_type: 'organization')
      expect(org).to be_organization
    end

    it 'rejects an unknown agent_type' do
      expect { described_class.new(agent_type: 'robot') }.to raise_error(ArgumentError)
    end

    it 'coerces a blank agent_type back to the default (a blank form select must not hit the NOT NULL column)' do
      contributor = described_class.create!(display_name: 'Myself', agent_type: '')
      expect(contributor.reload.agent_type).to eq('person')
    end

    it 'exposes .person and .organization scopes' do
      person = described_class.create!(display_name: 'Ada')
      org = described_class.create!(display_name: 'Acme', agent_type: 'organization')
      expect(described_class.person).to include(person)
      expect(described_class.person).not_to include(org)
      expect(described_class.organization).to include(org)
      expect(described_class.organization).not_to include(person)
    end
  end

  describe 'orcid (optional, unique when present)' do
    it 'allows many contributors with no orcid' do
      described_class.create!(display_name: 'No ORCID One')
      expect(described_class.new(display_name: 'No ORCID Two')).to be_valid
    end

    it 'stores a blank orcid as nil rather than an empty string' do
      contributor = described_class.create!(display_name: 'Blank ORCID', orcid: '')
      expect(contributor.orcid).to be_nil
    end

    it 'rejects a second contributor with the same orcid (case-insensitive)' do
      described_class.create!(display_name: 'First', orcid: 'https://orcid.org/0000-0002-1825-0097')
      dup = described_class.new(display_name: 'Second', orcid: 'HTTPS://ORCID.ORG/0000-0002-1825-0097')
      expect(dup).not_to be_valid
      expect(dup.errors[:orcid]).to be_present
    end

    it 'allows the same contributor to keep its orcid on update' do
      contributor = described_class.create!(display_name: 'Ada', orcid: 'https://orcid.org/0000-0001-2345-6789')
      contributor.display_name = 'Ada Lovelace'
      expect(contributor).to be_valid
    end
  end

  describe 'affiliations (multi-valued, jsonb-backed)' do
    it 'stores an array of affiliations in the metadata blob' do
      contributor = described_class.create!(display_name: 'Ada', affiliations: ['Analytical Society', 'Westminster'])
      expect(contributor.reload.affiliations).to eq(['Analytical Society', 'Westminster'])
      expect(contributor.metadata['affiliation']).to eq(['Analytical Society', 'Westminster'])
    end

    it 'trims and drops blank entries on write' do
      contributor = described_class.create!(display_name: 'Ada', affiliations: ['  Westminster  ', '', '   '])
      expect(contributor.affiliations).to eq(['Westminster'])
    end

    it 'reads a legacy single-string value back as a one-element array (no migration)' do
      # Simulate the previous single-string storage shape directly in the blob.
      contributor = described_class.create!(display_name: 'Ada', metadata: { 'affiliation' => 'Analytical Society' })
      expect(contributor.reload.affiliations).to eq(['Analytical Society'])
    end

    it 'is empty when unset' do
      expect(described_class.new(display_name: 'Ada').affiliations).to eq([])
    end
  end

  describe 'name_identifiers (multi-valued {value, scheme}, jsonb-backed, distinct from orcid)' do
    it 'stores a list of {value, scheme} hashes in the metadata blob' do
      contributor = described_class.create!(
        display_name: 'Ada',
        name_identifiers: [{ 'value' => '0000000121032683', 'scheme' => 'ISNI' },
                           { 'value' => 'https://ror.org/02mhbdp94', 'scheme' => 'ROR' }]
      )
      expect(contributor.reload.name_identifiers).to eq(
        [{ 'value' => '0000000121032683', 'scheme' => 'ISNI' },
         { 'value' => 'https://ror.org/02mhbdp94', 'scheme' => 'ROR' }]
      )
    end

    it 'accepts symbol-keyed entries and drops blank-value entries on write' do
      contributor = described_class.create!(
        display_name: 'Ada',
        name_identifiers: [{ value: '  0000000121032683  ', scheme: 'ISNI' }, { value: '', scheme: 'ROR' }]
      )
      expect(contributor.name_identifiers).to eq([{ 'value' => '0000000121032683', 'scheme' => 'ISNI' }])
    end

    it 'reads a legacy single name_identifier (+ scheme) back as a one-element list (no migration)' do
      contributor = described_class.create!(
        display_name: 'Ada',
        metadata: { 'name_identifier' => '0000000121032683', 'name_identifier_scheme' => 'ISNI' }
      )
      expect(contributor.reload.name_identifiers).to eq([{ 'value' => '0000000121032683', 'scheme' => 'ISNI' }])
    end

    it 'is empty when unset and does not collide with affiliations in the same blob' do
      contributor = described_class.create!(display_name: 'Ada', affiliations: ['Westminster'])
      expect(contributor.reload.name_identifiers).to eq([])
      expect(contributor.affiliations).to eq(['Westminster'])
    end
  end

  describe 'claim state (user_id reserved; unused in Phase 1)' do
    it 'is unclaimed when user_id is nil' do
      contributor = described_class.create!(display_name: 'Ada')
      expect(contributor).not_to be_claimed
      expect(described_class.unclaimed).to include(contributor)
      expect(described_class.claimed).not_to include(contributor)
    end

    it 'is claimed when user_id is set' do
      contributor = described_class.create!(display_name: 'Ada', user_id: 42)
      expect(contributor).to be_claimed
      expect(described_class.claimed).to include(contributor)
      expect(described_class.unclaimed).not_to include(contributor)
    end
  end
end
