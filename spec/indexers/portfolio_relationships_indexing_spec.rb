# frozen_string_literal: true

require 'rails_helper'

# Flex-mode (HYRAX_FLEXIBLE=true, the suite default) round-trip for the
# `relationships` compound (the patch cables). Entry keys are the M3 members'
# `name:`s; Solr fields are the derived `<compound>_<name>_<suffix>` names from
# each member's type (work_or_url -> _ssim, controlled -> _sim, string -> _sim +
# _tesim), except `note`, which declares an explicit `indexing:` override
# (full-text only). The display blob is what the read-only relationship view
# reads back.
RSpec.describe 'Portfolio relationships indexing', :clean_repo do
  let(:target) { Hyrax.persister.save(resource: Portfolio.new(title: ['Target work'])) }

  let(:relationship) do
    {
      'item' => target.id.to_s,
      'type' => 'source-of',
      'type_other' => 'Remixes',
      'type_other_inverse' => 'Is remixed by',
      'position' => '1',
      'note' => 'The model is the source for the export'
    }
  end

  let(:resource) do
    Hyrax.persister.save(resource: Portfolio.new(
      title: ['Source work'],
      relationships: [relationship]
    ))
  end

  let(:doc) { PortfolioIndexer.new(resource:).to_solr }

  it 'indexes each subfield into its derived (or overridden) Solr field' do
    expect(doc['relationships_item_ssim']).to include(target.id.to_s)
    expect(doc['relationships_type_sim']).to include('source-of')
    expect(doc['relationships_position_sim']).to include('1')
    expect(doc['relationships_note_tesim'])
      .to include(a_string_including('source for the export'))
    expect(doc['relationships_type_other_tesim']).to include('Remixes')
    expect(doc['relationships_type_other_inverse_tesim']).to include('Is remixed by')
  end

  it 'does not facet the free-text note (explicit indexing override)' do
    expect(doc).not_to have_key('relationships_note_sim')
  end

  it 'writes the full entry into the relationships display blob' do
    entries = Hyrax::SolrDocument::Metadata::Solr::CompoundEntries.coerce(doc['relationships_json_ss'])
    expect(entries.size).to eq(1)
    expect(entries.first).to include(
      'item' => target.id.to_s,
      'type' => 'source-of',
      'type_other' => 'Remixes',
      'type_other_inverse' => 'Is remixed by',
      'position' => '1'
    )
  end
end
