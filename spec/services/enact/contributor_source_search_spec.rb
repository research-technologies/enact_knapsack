# frozen_string_literal: true

require 'rails_helper'

# The `:contributors` linked_record source's search proc (registered in
# config/initializers/enact_linked_records.rb) backs the picker autocomplete.
# Beyond the generic `{ id:, label:, value: }` it returns `orcid` and a primary
# `affiliation`, so the picker can render a distinguishing row and a curator can
# tell two same-named contributors apart instead of creating a duplicate.
# Exercised through the generic resolver, as the QA authority does.
RSpec.describe 'Enact :contributors linked_record search proc' do
  subject(:results) { Hyrax::CompoundLinkedRecordResolver.search(:contributors, query) }

  let!(:ada) do
    Enact::Contributor.create!(display_name: 'Ada Lovelace',
                               orcid: 'https://orcid.org/0000-0002-1825-0097',
                               affiliations: ['Analytical Society', 'Westminster'])
  end

  context 'matching by name' do
    let(:query) { 'lovelace' }

    it 'returns a row carrying id/label/value plus orcid and the primary affiliation' do
      row = results.find { |r| r[:id] == ada.id.to_s }
      expect(row).to include(
        id: ada.id.to_s, label: 'Ada Lovelace', value: ada.id.to_s,
        orcid: 'https://orcid.org/0000-0002-1825-0097', affiliation: 'Analytical Society'
      )
    end
  end

  context 'when a contributor has no affiliation' do
    let!(:grace) { Enact::Contributor.create!(display_name: 'Grace Hopper') }
    let(:query) { 'hopper' }

    it 'returns a nil affiliation rather than raising' do
      row = results.find { |r| r[:id] == grace.id.to_s }
      expect(row[:affiliation]).to be_nil
      expect(row[:orcid]).to be_nil
    end
  end

  context 'matching by affiliation (broadened search reaches the picker)' do
    let(:query) { 'analytical' }

    it 'finds the contributor by an affiliation substring' do
      expect(results.map { |r| r[:id] }).to include(ada.id.to_s)
    end
  end
end
