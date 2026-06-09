# frozen_string_literal: true

require 'rails_helper'

# Flex-mode (HYRAX_FLEXIBLE=true, the suite default) round-trip for the
# `relationships` compound (the patch cables). Asserts that a stored entry's
# subfields land in their declared Solr fields and in the display blob, which is
# what the read-only relationship view reads back.
RSpec.describe 'Portfolio relationships indexing', :clean_repo do
  let(:target) { Hyrax.persister.save(resource: Portfolio.new(title: ['Target work'])) }

  let(:relationship) do
    {
      'relationship_item' => target.id.to_s,
      'relationship_type' => 'source-of',
      'relationship_position' => '1',
      'relationship_note' => 'The model is the source for the export'
    }
  end

  let(:resource) do
    Hyrax.persister.save(resource: Portfolio.new(
      title: ['Source work'],
      relationships: [relationship]
    ))
  end

  let(:doc) { PortfolioIndexer.new(resource:).to_solr }

  it 'indexes each subfield into its declared Solr field' do
    expect(doc['relationships_item_ssim']).to include(target.id.to_s)
    expect(doc['relationships_type_sim']).to include('source-of')
    expect(doc['relationships_position_ssim']).to include('1')
    expect(doc['relationships_note_tesim'])
      .to include(a_string_including('source for the export'))
  end

  it 'writes the full entry into the relationships display blob' do
    entries = Hyrax::Solr::CompoundEntries.coerce(doc['relationships_json_ss'])
    expect(entries.size).to eq(1)
    expect(entries.first).to include(
      'relationship_item' => target.id.to_s,
      'relationship_type' => 'source-of',
      'relationship_position' => '1'
    )
  end
end
