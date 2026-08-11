# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Enact::ItemSubtypeLabels do
  let(:sculpture) { 'https://schema.org/Sculpture' }

  describe '.label_for' do
    it 'labels a subtype from each of the four authorities' do
      %w[artefact_type event_type literature_type collection_type].each do |authority|
        path = HykuKnapsack::Engine.root.join('config', 'authorities', "#{authority}.yml")
        term = YAML.load_file(path)['terms'].first

        expect(described_class.label_for(term['id'])).to eq(term['term'])
      end
    end

    it 'returns the value unchanged when it is not a known subtype' do
      expect(described_class.label_for('https://example.org/not-a-subtype'))
        .to eq('https://example.org/not-a-subtype')
    end

    it 'returns the value unchanged when it is blank' do
      expect(described_class.label_for(nil)).to be_nil
      expect(described_class.label_for('')).to eq('')
    end
  end

  # The per-type YAMLs are also read by Hyrax's own label lookup, which does
  # find(id).fetch('term') — a file keyed on `label` silently yields the raw URI.
  describe 'the source authority files' do
    it 'keys every term on `term` so Hyrax can label it too' do
      %w[artefact_type event_type literature_type collection_type].each do |authority|
        path = HykuKnapsack::Engine.root.join('config', 'authorities', "#{authority}.yml")
        untermed = YAML.load_file(path)['terms'].reject { |t| t.key?('term') }

        expect(untermed).to be_empty,
                            "#{authority}.yml has #{untermed.size} term(s) missing a `term` key"
      end
    end

    it 'resolves through Hyrax::TolerantSelectService, as the review page does' do
      service = Hyrax::TolerantSelectService.new('artefact_type')

      expect(service.label(sculpture) { nil }).to eq('Physical Object - Sculpture')
    end
  end
end
