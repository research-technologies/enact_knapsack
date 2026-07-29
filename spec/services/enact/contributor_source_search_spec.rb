# frozen_string_literal: true

require 'rails_helper'

# The `:contributors` linked_record source's `search` and `similar` procs
# (registered in config/initializers/enact_linked_records.rb) back the picker
# autocomplete and its "did you mean" duplicate check. Beyond the generic
# `{ id:, label:, value: }`, each row carries an optional `detail` string
# (ORCID · affiliation) the picker renders as a muted second line, so a curator
# can tell two same-named contributors apart instead of creating a duplicate.
# Exercised through the generic resolver, as the QA authorities do.
RSpec.describe 'Enact :contributors linked_record picker procs' do
  let!(:ada) do
    Enact::Contributor.create!(display_name: 'Ada Lovelace',
                               orcid: 'https://orcid.org/0000-0002-1825-0097',
                               affiliations: ['Analytical Society', 'Westminster'])
  end

  describe 'search' do
    subject(:results) { Hyrax::CompoundLinkedRecordResolver.search(:contributors, query) }

    context 'matching by name' do
      let(:query) { 'lovelace' }

      it 'returns a row carrying id/label/value plus a detail line (ORCID · affiliation)' do
        row = results.find { |r| r[:id] == ada.id.to_s }
        expect(row).to include(
          id: ada.id.to_s, label: 'Ada Lovelace', value: ada.id.to_s,
          detail: 'https://orcid.org/0000-0002-1825-0097 · Analytical Society'
        )
      end
    end

    context 'when a contributor has no orcid or affiliation' do
      let!(:grace) { Enact::Contributor.create!(display_name: 'Grace Hopper') }
      let(:query) { 'hopper' }

      it 'returns a nil detail rather than raising' do
        row = results.find { |r| r[:id] == grace.id.to_s }
        expect(row[:detail]).to be_nil
      end
    end

    context 'matching by affiliation (broadened search reaches the picker)' do
      let(:query) { 'analytical' }

      it 'finds the contributor by an affiliation substring' do
        expect(results.map { |r| r[:id] }).to include(ada.id.to_s)
      end
    end
  end

  describe 'similar (fuzzy "did you mean" check)' do
    subject(:results) { Hyrax::CompoundLinkedRecordResolver.similar(:contributors, query) }

    context 'a typo/variant the substring search would miss' do
      let!(:john) do
        Enact::Contributor.create!(display_name: 'John Smith',
                                   orcid: 'https://orcid.org/0000-0001-2345-6789',
                                   affiliations: ['Nottingham'])
      end
      let(:query) { 'Jon Smith' }

      it 'surfaces the fuzzy match with the same detail-bearing row shape' do
        row = results.find { |r| r[:id] == john.id.to_s }
        expect(row).to include(
          id: john.id.to_s, label: 'John Smith', value: john.id.to_s,
          detail: 'https://orcid.org/0000-0001-2345-6789 · Nottingham'
        )
      end
    end

    context 'a blank term' do
      let(:query) { '' }

      it 'returns no candidates' do
        expect(results).to eq([])
      end
    end
  end
end
