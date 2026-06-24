# frozen_string_literal: true

require 'rails_helper'

# The `:contributors` linked_record source's `match` proc (registered in
# config/initializers/enact_linked_records.rb): an exact, single-row lookup used
# by find-or-create on import, distinct from the fuzzy picker `search`. ORCID
# wins when present and it hits; a present-but-unmatched ORCID falls through to
# an exact, case-insensitive display_name match; with no ORCID the match is by
# name alone. Exercised through the generic resolver, as the importer does.
RSpec.describe 'Enact :contributors linked_record match proc' do
  let!(:ada) { Enact::Contributor.create!(display_name: 'Ada Lovelace', orcid: 'https://orcid.org/0000-0002-1825-0097') }

  describe 'exact name matching' do
    it 'returns the existing record for an exact, case-insensitive name' do
      expect(Hyrax::CompoundLinkedRecordResolver.match(:contributors, display_name: 'ada lovelace')).to eq(ada)
    end

    it 'does not fuzzily match a near name (unlike the picker search)' do
      Enact::Contributor.create!(display_name: 'Ada Lovelaces')
      expect(Hyrax::CompoundLinkedRecordResolver.match(:contributors, display_name: 'Ada Lovelace')).to eq(ada)
    end

    it 'returns nil on a miss and for a blank name' do
      expect(Hyrax::CompoundLinkedRecordResolver.match(:contributors, display_name: 'Nobody Here')).to be_nil
      expect(Hyrax::CompoundLinkedRecordResolver.match(:contributors, display_name: ' ')).to be_nil
    end
  end

  describe 'ORCID precedence' do
    it 'matches on ORCID even when the supplied name differs' do
      found = Hyrax::CompoundLinkedRecordResolver.match(
        :contributors, display_name: 'A. Lovelace', orcid: 'https://orcid.org/0000-0002-1825-0097'
      )
      expect(found).to eq(ada)
    end

    it 'falls back to the name when the ORCID matches nobody' do
      found = Hyrax::CompoundLinkedRecordResolver.match(
        :contributors, display_name: 'Ada Lovelace', orcid: 'https://orcid.org/0000-0000-0000-0000'
      )
      expect(found).to eq(ada)
    end
  end

  describe 'find_or_create' do
    it 'reuses the existing record rather than creating a duplicate' do
      expect do
        result = Hyrax::CompoundLinkedRecordResolver.find_or_create(:contributors, display_name: 'Ada Lovelace')
        expect(result).to eq(ada)
      end.not_to change(Enact::Contributor, :count)
    end

    it 'creates a person contributor when nothing matches' do
      result = nil
      expect do
        result = Hyrax::CompoundLinkedRecordResolver.find_or_create(:contributors, display_name: 'Grace Hopper')
      end.to change(Enact::Contributor, :count).by(1)
      expect(result.display_name).to eq('Grace Hopper')
      expect(result.agent_type).to eq('person')
    end
  end

  # Both procs accept string-keyed attrs, not only symbols — so a caller passing
  # a string-keyed Hash (or ActionController::Parameters) matches and creates
  # correctly rather than reading every key as blank.
  describe 'string-keyed attributes' do
    it 'matches an existing record from string keys' do
      expect(Hyrax::CompoundLinkedRecordResolver.match(:contributors, 'display_name' => 'Ada Lovelace')).to eq(ada)
    end

    it 'creates from string keys with attributes assigned' do
      created = Hyrax::CompoundLinkedRecordResolver.create(
        :contributors, 'display_name' => 'Grace Hopper', 'orcid' => 'https://orcid.org/0000-0003-0001-0002'
      )
      expect(created).to be_persisted
      expect(created.display_name).to eq('Grace Hopper')
      expect(created.orcid).to eq('https://orcid.org/0000-0003-0001-0002')
    end
  end
end
