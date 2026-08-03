# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Hyrax::CitationsBehaviors::NameBehaviorDecorator, type: :helper do
  let(:credit) { double('credit', label: 'McLean, Bruce') }
  let(:work) { double('presenter', creator: [], solr_document: double('doc')) }

  before do
    allow(Enact::WorkContributors).to receive(:new).and_return(double('contributors', credits: [credit]))
  end

  describe '#all_authors' do
    it 'falls back to the contributors compound when creator is empty' do
      expect(helper.all_authors(work)).to eq(['McLean, Bruce'])
    end

    it 'prefers a real creator and does not consult the contributors' do
      allow(work).to receive(:creator).and_return(['Solo, Ada'])
      expect(Enact::WorkContributors).not_to receive(:new)

      expect(helper.all_authors(work)).to eq(['Solo, Ada'])
    end

    it 'applies the caller\'s block to the fallback names, as author_list relies on' do
      expect(helper.all_authors(work, &:upcase)).to eq(['MCLEAN, BRUCE'])
    end
  end

  describe 'reaching the formatters' do
    # BaseFormatter includes NameBehavior directly, so this is what proves the prepend
    # lands where the citation output is actually built.
    it 'is in the ancestry of the citation formatters' do
      expect(Hyrax::CitationsBehaviors::Formatters::ApaFormatter.ancestors)
        .to include(described_class)
    end
  end
end
