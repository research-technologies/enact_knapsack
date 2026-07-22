# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Enact::DepositWizard::SubtypeSuggestions do
  # The service memoizes the compiled authorities; clear it so each example
  # reads the real YAML fresh.
  before do
    described_class.instance_variables.each { |ivar| described_class.remove_instance_variable(ivar) }
  end

  describe '.all_subtypes' do
    it 'compiles every subtype across the four authorities, tagged with work type and badge' do
      subtypes = described_class.all_subtypes

      expect(subtypes).to be_present
      work_types = subtypes.map { |s| s[:work_type] }.uniq
      expect(work_types).to contain_exactly(
        'PortfolioArtefact', 'PortfolioEvent', 'PortfolioLiterature', 'PortfolioItemCollection'
      )
    end

    it 'routes each subtype id to exactly one work type (ids are globally unique)' do
      ids = described_class.all_subtypes.map { |s| s[:id] }
      expect(ids).to eq(ids.uniq)
    end

    it 'derives the badge from the owning authority file' do
      photograph = described_class.find('https://schema.org/Photograph')
      expect(photograph[:work_type]).to eq('PortfolioArtefact')
      expect(photograph[:badge]).to eq('Artefact')
    end
  end

  describe '.for_suffix' do
    it 'suggests the subtypes whose file_suffixes include the extension' do
      labels = described_class.for_suffix('jpg').map { |s| s[:label] }
      expect(labels).to include('Visual Media - StillImage - Photograph')
    end

    it 'matches case-insensitively and tolerates a leading dot' do
      expect(described_class.for_suffix('JPG')).to eq(described_class.for_suffix('jpg'))
      expect(described_class.for_suffix('.jpg')).to eq(described_class.for_suffix('jpg'))
    end

    it 'suggests across work types for a shared suffix' do
      work_types = described_class.for_suffix('pdf').map { |s| s[:work_type] }.uniq
      expect(work_types.size).to be > 1
    end

    it 'returns an empty list for an unknown or blank extension' do
      expect(described_class.for_suffix('xyz')).to eq([])
      expect(described_class.for_suffix('')).to eq([])
      expect(described_class.for_suffix(nil)).to eq([])
    end
  end

  describe '.work_type_for' do
    it 'returns the owning work type for a known subtype id' do
      expect(described_class.work_type_for('https://schema.org/ExhibitionEvent')).to eq('PortfolioEvent')
    end

    it 'returns nil for an unknown id' do
      expect(described_class.work_type_for('https://example.com/nope')).to be_nil
    end
  end

  describe '.compiled' do
    it 'is present so the wizard enables the guided path' do
      expect(described_class.compiled).to be_present
    end
  end
end
