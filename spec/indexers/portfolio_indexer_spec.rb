# frozen_string_literal: true

require 'rails_helper'
require 'hyrax/specs/shared_specs/indexers'

RSpec.describe PortfolioIndexer do
  let(:indexer_class) { described_class }
  let!(:resource) { Hyrax.persister.save(resource: Portfolio.new) }

  it_behaves_like 'a Hyrax::Resource indexer'

  describe 'compound flattening', :clean_repo do
    # Hash keys must match the M3 subproperty names declared in
    # config/metadata_profiles/m3_profile.yaml. The schema-driven indexer
    # calls `resource.try(<subproperty_name>)` (see
    # Hyrax::SchemaLoader#index_rules_for), and the generated reader
    # extracts the hash entry whose key is exactly the subproperty name.
    let(:contributor) do
      { 'contributor_given_name' => 'Avery', 'contributor_family_name' => 'Brooks',
        'contributor_name' => 'Avery Brooks' }
    end
    let(:license) { { 'license_rights_label' => 'CC BY 4.0' } }
    let(:funder) { { 'funder_name' => 'AHRC' } }
    let(:unit) { { 'organisational_unit_name' => 'School of Music' } }
    let(:identifier) { { 'identifier_value' => 'doi:10.1234/foo', 'identifier_type' => 'doi' } }
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
      doc = described_class.new(resource:).to_solr
      expect(doc['contributor_name_tesim']).to include('Avery Brooks')
      expect(doc['license_label_tesim']).to include('CC BY 4.0')
      expect(doc['funder_name_tesim']).to include('AHRC')
      expect(doc['organisational_unit_name_tesim']).to include('School of Music')
      expect(doc['identifier_value_tesim']).to include(a_string_including('doi:10.1234/foo'))
    end
  end
end
