# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Hyrax::MediaViewerService do
  describe 'controlled-vocabulary source registration' do
    subject(:services) { Hyrax::ControlledVocabularies.services }

    it 'maps the media_viewer source to this service' do
      expect(services['media_viewer']).to eq('Hyrax::MediaViewerService')
    end

    it 'merges onto the host sources rather than replacing them' do
      expect(services).to include('rights_statements' => 'Hyrax::RightsStatementService')
    end
  end

  describe 'authority options' do
    it 'offers the four viewers as [label, id] pairs from the knapsack authority' do
      expect(described_class.select_all_options).to contain_exactly(
        ['Universal Viewer', 'universal_viewer'],
        ['Clover IIIF', 'clover'],
        ['Ramp (AV)', 'ramp'],
        ['PDF.js', 'pdf_js']
      )
    end

    it 'treats terms with no `active:` key as active' do
      expect(described_class.active?('clover')).to be(true)
    end
  end
end
