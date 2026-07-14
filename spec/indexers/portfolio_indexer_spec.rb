# frozen_string_literal: true

require 'rails_helper'
require 'hyrax/specs/shared_specs/indexers'

RSpec.describe PortfolioIndexer do
  let(:indexer_class) { described_class }
  let!(:resource) { Hyrax.persister.save(resource: Portfolio.new) }

  it_behaves_like 'a Hyrax::Resource indexer'

  describe 'compound flattening', :clean_repo do
    # Hash keys are each member's `name:` from
    # config/metadata_profiles/m3_profile.yaml (the key inside each entry).
    # Hyrax::Indexers::CompoundIndexer derives the Solr field names per member
    # as `<compound>_<name>_<suffix>` from the member's type, so a string
    # member lands in `<compound>_<name>_tesim` (and `_sim`).
    # A contributors entry is a `contributor` linked_record reference (a record
    # id -> `contributors_contributor_ssim`), a controlled `role`, and a
    # free-text `role_other` (-> `contributors_role_other_tesim`).
    let(:contributor) do
      { 'contributor' => '42', 'role' => 'conceptualization', 'role_other' => 'Sound design' }
    end
    let(:funder) { { 'funder_name' => 'AHRC' } }
    let(:resource) do
      Hyrax.persister.save(resource: Portfolio.new(
        title: ['Indexed portfolio'],
        contributors: [contributor],
        funding_references: [funder]
      ))
    end

    it 'writes derived <compound>_<name>_tesim fields to Solr' do
      doc = described_class.new(resource:).to_solr
      # The linked_record contributor ref indexes its id for reverse lookup;
      # the free-text role_other indexes full-text.
      expect(doc['contributors_contributor_ssim']).to include('42')
      expect(doc['contributors_role_other_tesim']).to include(a_string_including('Sound design'))
      expect(doc['funding_references_funder_name_tesim']).to include('AHRC')
    end
  end
end
