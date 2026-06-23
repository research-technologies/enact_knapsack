# frozen_string_literal: true

require 'rails_helper'

# Reverse-lookup: the works a given contributor is credited on. Mirrors
# Enact::RelationshipGraph's inbound design — the edge is stored once on the
# work's `contributors` compound, found via a Solr reverse lookup on the derived
# `contributors_contributor_ssim` field. Access-scoped to the supplied ability so
# a profile page only lists works the viewer may see. Each work appears once,
# with all of that contributor's roles on it joined.
RSpec.describe Enact::ContributorGraph do
  let(:ability) { instance_double(Ability) }
  let(:contributor) { instance_double(Enact::Contributor, id: 42) }
  let(:graph) { described_class.new(contributor, ability:) }

  # A SolrQueryService double whose chain (with_field_pairs / accessible_by)
  # returns itself and finally yields the given docs from #solr_documents.
  def stub_query_service(docs)
    service = instance_double(Hyrax::SolrQueryService)
    allow(Hyrax::SolrQueryService).to receive(:new).and_return(service)
    allow(service).to receive(:with_field_pairs).and_return(service)
    allow(service).to receive(:accessible_by).and_return(service)
    allow(service).to receive(:solr_documents).and_return(docs)
    service
  end

  # A stand-in Solr doc carrying the raw contributors JSON blob and the bits the
  # graph reads for title/path/thumbnail/type.
  def work_doc(id:, title:, entries:, thumbnail: nil, type_label: 'Artefact')
    SolrDocument.new(
      'id' => id,
      'title_tesim' => [title],
      'has_model_ssim' => ['Portfolio'],
      'human_readable_type_tesim' => [type_label],
      'thumbnail_path_ss' => thumbnail,
      'contributors_json_ss' => entries.to_json
    )
  end

  describe '#works' do
    it 'scopes the reverse lookup to the contributor id and the ability' do
      service = stub_query_service([])
      graph.works
      expect(service).to have_received(:with_field_pairs)
        .with(field_pairs: { 'contributors_contributor_ssim' => '42' })
      expect(service).to have_received(:accessible_by).with(ability:)
    end

    it 'returns one entry per work with that contributor, roles joined' do
      docs = [
        work_doc(
          id: 'work-1', title: 'First Work',
          entries: [
            { 'contributor' => '42', 'role' => 'conceptualization' },
            { 'contributor' => '42', 'role' => 'data-curation' },
            { 'contributor' => '99', 'role' => 'writing-original-draft' }
          ]
        )
      ]
      stub_query_service(docs)

      works = graph.works
      expect(works.length).to eq(1)
      expect(works.first.id).to eq('work-1')
      expect(works.first.title).to eq('First Work')
      # The graph passes the stored role codes through verbatim; label
      # resolution happens at the view via Enact::ContributorRolesService.
      expect(works.first.roles).to eq(['conceptualization', 'data-curation'])
    end

    it 'carries the work thumbnail and type label for the credited-works list' do
      docs = [work_doc(id: 'work-1', title: 'First Work', thumbnail: '/assets/work-thumb.png',
                       type_label: 'Event', entries: [{ 'contributor' => '42', 'role' => 'methodology' }])]
      stub_query_service(docs)

      expect(graph.works.first.thumbnail).to eq('/assets/work-thumb.png')
      expect(graph.works.first.type_label).to eq('Event')
    end

    it 'omits roles for entries belonging to other contributors' do
      docs = [
        work_doc(
          id: 'work-1', title: 'First Work',
          entries: [{ 'contributor' => '99', 'role' => 'writing-original-draft' }]
        )
      ]
      stub_query_service(docs)

      # The Solr query already filters to docs mentioning the contributor, but a
      # doc may carry other contributors' entries too; only ours contribute roles.
      expect(graph.works.first.roles).to eq([])
    end

    it 'returns [] when the contributor has no id' do
      stub_query_service([])
      no_id = instance_double(Enact::Contributor, id: nil)
      expect(described_class.new(no_id, ability:).works).to eq([])
    end
  end
end
