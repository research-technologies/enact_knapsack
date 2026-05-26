# frozen_string_literal: true

require 'rails_helper'
require 'hyrax/specs/shared_specs/indexers'

RSpec.describe PortfolioItemResourceIndexer do
  let(:indexer_class) { described_class }
  let!(:resource) { Hyrax.persister.save(resource: PortfolioItemResource.new) }

  it_behaves_like 'a Hyrax::Resource indexer'

  describe 'compound flattening including geo_locations', :clean_repo do
    let(:resource) do
      Hyrax.persister.save(resource: PortfolioItemResource.new(
        title: ['Indexed item'],
        portfolio_item_type: 'Event',
        contributors: [{ 'contributor_name' => 'Avery Brooks' }],
        geo_locations: [{ 'place_name' => 'Tate Modern' }]
      ))
    end

    it 'writes geo_place_name to Solr alongside the shared flattened fields' do
      doc = described_class.new(resource: resource).to_solr
      expect(doc['contributor_label_tesim']).to include('Avery Brooks')
      expect(doc['geo_place_name_tesim']).to include('Tate Modern')
    end
  end
end
