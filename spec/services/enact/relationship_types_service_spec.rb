# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Enact::RelationshipTypesService do
  describe '.inverse' do
    it 'returns the paired DataCite term' do
      expect(described_class.inverse('cites')).to eq('iscitedby')
      expect(described_class.inverse('iscitedby')).to eq('cites')
    end

    it 'returns the term itself for a symmetric relation' do
      expect(described_class.inverse('isidenticalto')).to eq('isidenticalto')
    end

    it 'falls back to the code itself when no inverse is declared' do
      expect(described_class.inverse('ispublishedin')).to eq('ispublishedin')
      expect(described_class.inverse('unknown-type')).to eq('unknown-type')
    end
  end

  describe '.color' do
    it 'returns the declared colour' do
      expect(described_class.color('cites')).to eq('#c9544b')
    end

    it 'falls back to the neutral colour for an uncoloured or unknown term' do
      expect(described_class.color('issupplementto')).to eq(described_class::FALLBACK_COLOR)
      expect(described_class.color('unknown-type')).to eq(described_class::FALLBACK_COLOR)
    end
  end

  describe '.label' do
    it 'returns the authority term' do
      expect(described_class.label('iscitedby')).to eq('Is Cited By')
    end

    it 'humanizes an unknown code' do
      expect(described_class.label('made-up-type')).to eq('Made up type')
    end
  end

  describe '.datacite' do
    it 'returns the DataCite relationType' do
      expect(described_class.datacite('issupplementto')).to eq('IsSupplementTo')
    end

    it 'is nil for a legacy term' do
      expect(described_class.datacite('sequence')).to be_nil
    end
  end

  describe 'legacy terms' do
    it 'resolves inverses for edges stored under the pre-DataCite vocabulary' do
      expect(described_class.inverse('source-of')).to eq('derived-from')
      expect(described_class.inverse('pair-with')).to eq('pair-with')
    end

    it 'excludes them from the deposit dropdown' do
      active_ids = Hyrax::TolerantSelectService.new('relationship_types').select_active_options.map(&:last)
      expect(active_ids).to include('cites')
      expect(active_ids).not_to include('sequence', 'source-of')
    end
  end
end
