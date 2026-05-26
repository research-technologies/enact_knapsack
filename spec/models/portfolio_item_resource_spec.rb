# frozen_string_literal: true

require 'rails_helper'
require 'hyrax/specs/shared_specs/hydra_works'

RSpec.describe PortfolioItemResource do
  subject(:work) { described_class.new }

  it_behaves_like 'a Hyrax::Work'

  describe 'schema-driven scalar attributes' do
    it { is_expected.to respond_to(:portfolio_item_type) }
    it { is_expected.to respond_to(:item_subtype) }
    it { is_expected.to respond_to(:media_type) }
    it { is_expected.to respond_to(:related_item) }
    it { is_expected.to respond_to(:file_access_level) }
    it { is_expected.to respond_to(:place_of_publication) }
    it { is_expected.to respond_to(:extent) }
    it { is_expected.to respond_to(:extent_type) }
    it { is_expected.to respond_to(:collection_order) }
  end

  describe 'schema-driven compound attributes' do
    it { is_expected.to respond_to(:contributors) }
    it { is_expected.to respond_to(:identifiers) }
    it { is_expected.to respond_to(:funding_references) }
    it { is_expected.to respond_to(:organisational_units) }
    it { is_expected.to respond_to(:geo_locations) }
    it { is_expected.to respond_to(:licenses) }
  end

  describe 'compound round-trip via persister', :clean_repo do
    let(:geo_location) do
      { 'place_name' => 'Tate Modern', 'point_latitude' => '51.5076', 'point_longitude' => '-0.0994' }
    end

    it 'persists and reloads geo_locations hash entries' do
      work.title = ['Test item']
      work.portfolio_item_type = 'Event'
      work.item_subtype = 'exhibition'
      work.geo_locations = [geo_location]

      saved = Hyrax.persister.save(resource: work)
      reloaded = Hyrax.query_service.find_by(id: saved.id)

      expect(reloaded.geo_locations.first['place_name']).to eq('Tate Modern')
      expect(reloaded.geo_locations.first['point_latitude']).to eq('51.5076')
    end
  end
end
