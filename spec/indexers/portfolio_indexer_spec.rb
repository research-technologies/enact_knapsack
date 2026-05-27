# frozen_string_literal: true

require 'rails_helper'
require 'hyrax/specs/shared_specs/indexers'

RSpec.describe PortfolioIndexer do
  let(:indexer_class) { described_class }
  let!(:resource) { Hyrax.persister.save(resource: Portfolio.new) }

  it_behaves_like 'a Hyrax::Resource indexer'

  describe 'compound flattening', :clean_repo do
    let(:contributor) do
      { 'given_name' => 'Avery', 'family_name' => 'Brooks', 'contributor_name' => 'Avery Brooks' }
    end
    let(:license) { { 'rights_label' => 'CC BY 4.0' } }
    let(:funder) { { 'funder_name' => 'AHRC' } }
    let(:unit) { { 'name' => 'School of Music' } }
    let(:identifier) { { 'value' => 'doi:10.1234/foo', 'identifier_type' => 'doi' } }
    let(:resource) do
      Hyrax.persister.save(resource: Portfolio.new(
        title: ['Indexed portfolio'],
        contributors: [contributor],
        licenses: [license],
        funding_references: [funder],
        organisational_units: [unit],
        identifiers: [identifier]
      ))
    end

    it 'writes flattened *_label / *_value fields to Solr' do
      doc = described_class.new(resource: resource).to_solr
      expect(doc['contributor_label_tesim']).to include('Avery Brooks')
      expect(doc['license_label_tesim']).to include('CC BY 4.0')
      expect(doc['funder_label_tesim']).to include('AHRC')
      expect(doc['organisational_unit_label_tesim']).to include('School of Music')
      expect(doc['identifier_value_tesim']).to include(a_string_including('doi:10.1234/foo'))
    end
  end
end
