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

  describe '.matching (picker autocomplete / browse-index search)' do
    it 'matches on display_name (case-insensitive substring)' do
      ada = described_class.create!(display_name: 'Ada Lovelace')
      expect(described_class.matching('lovelace')).to include(ada)
    end

    it 'matches on orcid' do
      ada = described_class.create!(display_name: 'Ada', orcid: 'https://orcid.org/0000-0002-1825-0097')
      expect(described_class.matching('0000-0002-1825-0097')).to include(ada)
    end

    it 'matches on an affiliation stored in the metadata blob' do
      ada = described_class.create!(display_name: 'Ada', affiliations: ['Analytical Society'])
      other = described_class.create!(display_name: 'Grace', affiliations: ['US Navy'])
      results = described_class.matching('analytical')
      expect(results).to include(ada)
      expect(results).not_to include(other)
    end

    it 'matches on a name_identifier value stored in the metadata blob' do
      ada = described_class.create!(
        display_name: 'Ada',
        name_identifiers: [{ 'value' => '0000000121032683', 'scheme' => 'ISNI' }]
      )
      expect(described_class.matching('0000000121032683')).to include(ada)
    end

    it 'treats LIKE wildcards in the term literally (escaped)' do
      literal = described_class.create!(display_name: '100% Ada')
      plain = described_class.create!(display_name: 'Grace')
      results = described_class.matching('100%')
      expect(results).to include(literal)
      expect(results).not_to include(plain)
    end
  end

  describe '.similar_to (fuzzy name match for the create-form duplicate check)' do
    it 'finds a name that differs only by a typo (trigram similarity, not substring)' do
      john = described_class.create!(display_name: 'John Smith')
      expect(described_class.similar_to('Jon Smith')).to include(john)
    end

    it 'finds a spelling variant the substring search would miss' do
      smith = described_class.create!(display_name: 'John Smith')
      # A pure ILIKE '%John Smyth%' would not match "John Smith".
      expect(described_class.matching('John Smyth')).not_to include(smith)
      expect(described_class.similar_to('John Smyth')).to include(smith)
    end

    it 'excludes clearly dissimilar names' do
      described_class.create!(display_name: 'John Smith')
      grace = described_class.create!(display_name: 'Grace Hopper')
      expect(described_class.similar_to('Jon Smith')).not_to include(grace)
    end

    it 'orders the most similar first' do
      exact = described_class.create!(display_name: 'John Smith')
      variant = described_class.create!(display_name: 'Johnny Smithson')
      results = described_class.similar_to('John Smith').to_a
      expect(results.index(exact)).to be < results.index(variant)
    end

    it 'returns nothing for a blank term' do
      described_class.create!(display_name: 'John Smith')
      expect(described_class.similar_to('')).to be_empty
      expect(described_class.similar_to('   ')).to be_empty
    end
  end

  describe 'claim state' do
    it 'is unclaimed when user_id is nil' do
      contributor = described_class.create!(display_name: 'Ada')
      expect(contributor).not_to be_claimed
      expect(described_class.unclaimed).to include(contributor)
      expect(described_class.claimed).not_to include(contributor)
    end

    it 'is claimed when linked to a user' do
      contributor = described_class.create!(display_name: 'Ada', user: FactoryBot.create(:user))
      expect(contributor).to be_claimed
      expect(described_class.claimed).to include(contributor)
      expect(described_class.unclaimed).not_to include(contributor)
    end
  end

  describe 'the 1:1 user link' do
    let(:user) { FactoryBot.create(:user) }

    it 'links to a user' do
      contributor = described_class.create!(display_name: 'Ada', user:)
      expect(contributor.reload.user).to eq(user)
    end

    it 'refuses to link an organization to a user account' do
      org = described_class.new(display_name: 'Acme Lab', agent_type: 'organization', user:)
      expect(org).not_to be_valid
      expect(org.errors[:user_id]).to be_present
    end

    describe '#linkable?' do
      it 'is true for an unclaimed person' do
        expect(described_class.new(display_name: 'Ada')).to be_linkable
      end

      it 'is false once claimed' do
        expect(described_class.create!(display_name: 'Ada', user:)).not_to be_linkable
      end

      it 'is false for an organization' do
        expect(described_class.new(display_name: 'Acme Lab', agent_type: 'organization')).not_to be_linkable
      end

      # The scope must select exactly what the predicate answers true for.
      it 'agrees with the .linkable scope' do
        person = described_class.create!(display_name: 'Ada')
        claimed = described_class.create!(display_name: 'Grace', user:)
        org = described_class.create!(display_name: 'Acme Lab', agent_type: 'organization')

        expect(described_class.linkable).to include(person)
        expect(described_class.linkable).not_to include(claimed, org)
        expect([person, claimed, org].select(&:linkable?)).to eq([person])
      end
    end

    it 'rejects a second profile claiming the same user' do
      described_class.create!(display_name: 'Ada', user:)
      duplicate = described_class.new(display_name: 'Ada (dup)', user:)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:user_id]).to be_present
    end

    it 'enforces the 1:1 link in the database, not just in the model' do
      described_class.create!(display_name: 'Ada', user:)
      duplicate = described_class.create!(display_name: 'Ada (dup)')
      # rubocop:disable Rails/SkipsModelValidations -- bypassing the validation is
      # the point: this asserts the partial unique index, not the model callback.
      expect { duplicate.update_column(:user_id, user.id) }
        .to raise_error(ActiveRecord::RecordNotUnique)
      # rubocop:enable Rails/SkipsModelValidations
    end

    it 'allows any number of unlinked profiles' do
      described_class.create!(display_name: 'Ada')
      expect { described_class.create!(display_name: 'Grace') }.not_to raise_error
      expect(described_class.unclaimed.count).to eq(2)
    end

    describe '#editable_by?' do
      it 'is true for the linked user' do
        contributor = described_class.create!(display_name: 'Ada', user:)
        expect(contributor).to be_editable_by(user)
      end

      it 'is false for a different user' do
        contributor = described_class.create!(display_name: 'Ada', user:)
        expect(contributor).not_to be_editable_by(FactoryBot.create(:user))
      end

      it 'is false for an unclaimed profile' do
        expect(described_class.create!(display_name: 'Ada')).not_to be_editable_by(user)
      end

      it 'is false for nil (an anonymous visitor)' do
        contributor = described_class.create!(display_name: 'Ada', user:)
        expect(contributor).not_to be_editable_by(nil)
      end
    end

    describe '#linked_user' do
      it 'returns the linked user' do
        expect(described_class.create!(display_name: 'Ada', user:).linked_user).to eq(user)
      end

      it 'returns nil when the profile is unlinked' do
        expect(described_class.create!(display_name: 'Ada').linked_user).to be_nil
      end

      it 'returns nil when the linked user has been deleted' do
        contributor = described_class.create!(display_name: 'Ada', user:)
        user.destroy
        expect(contributor.reload.linked_user).to be_nil
      end
    end
  end
end
