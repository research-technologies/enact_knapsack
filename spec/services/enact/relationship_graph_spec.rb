# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Enact::RelationshipGraph, :clean_repo do
  # Persist + index a Portfolio so both the reverse-lookup Solr query and
  # CompoundWorkResolver (title/path) resolve against real documents. Indexes
  # directly through the indexer + SolrService so the spec does not depend on
  # which Valkyrie index adapter the suite is configured with.
  def index(resource)
    Hyrax::SolrService.add(PortfolioIndexer.new(resource:).to_solr, commit: true)
    resource
  end

  let(:source) { index(Hyrax.persister.save(resource: Portfolio.new(title: ['Source work']))) }
  let(:target) { index(Hyrax.persister.save(resource: Portfolio.new(title: ['Target work']))) }

  # Re-save the source carrying a relationship that points at target, then index
  # it so the edge is queryable. Returns the source's SolrDocument.
  def relate(from:, to:, type:, position: nil, note: nil)
    entry = { 'item' => to.id.to_s, 'type' => type }
    entry['position'] = position if position
    entry['note'] = note if note
    updated = Hyrax.persister.save(resource: Hyrax.query_service.find_by(id: from.id).tap do |r|
      r.relationships = [entry]
    end)
    index(updated)
    solr_doc_for(updated.id)
  end

  def solr_doc_for(id)
    ::SolrDocument.new(Hyrax::SolrService.query("{!field f=id}#{id}", rows: 1).first)
  end

  describe '#outbound' do
    it 'returns the source\'s own edges, resolved to internal targets' do
      doc = relate(from: source, to: target, type: 'source-of', note: 'why')
      edge = described_class.new(doc).outbound.first

      expect(edge.target_id).to eq(target.id.to_s)
      expect(edge.title).to eq('Target work')
      expect(edge.relation_type).to eq('source-of')
      expect(edge.note).to eq('why')
      expect(edge.path).to be_present
    end

    it 'orders sequenced edges by position' do
      other = index(Hyrax.persister.save(resource: Portfolio.new(title: ['Second target'])))
      entries = [
        { 'item' => other.id.to_s, 'type' => 'sequence', 'position' => '2' },
        { 'item' => target.id.to_s, 'type' => 'sequence', 'position' => '1' }
      ]
      updated = Hyrax.persister.save(resource: Hyrax.query_service.find_by(id: source.id).tap { |r| r.relationships = entries })
      index(updated)

      titles = described_class.new(solr_doc_for(updated.id)).outbound.map(&:title)
      expect(titles).to eq(['Target work', 'Second target'])
    end

    it 'emits external URLs as external edges (the URL is both title and path)' do
      updated = Hyrax.persister.save(resource: Hyrax.query_service.find_by(id: source.id).tap do |r|
        r.relationships = [{ 'item' => 'https://example.org/thing', 'type' => 'documents', 'note' => 'see also' }]
      end)
      index(updated)

      edge = described_class.new(solr_doc_for(updated.id)).outbound.first
      expect(edge.external).to be(true)
      expect(edge.title).to eq('https://example.org/thing')
      expect(edge.path).to eq('https://example.org/thing')
      expect(edge.relation_type).to eq('documents')
      expect(edge.note).to eq('see also')
    end

    it 'skips targets that do not resolve to an indexed work' do
      updated = Hyrax.persister.save(resource: Hyrax.query_service.find_by(id: source.id).tap do |r|
        r.relationships = [{ 'item' => 'nonexistent-id', 'type' => 'documents' }]
      end)
      index(updated)

      expect(described_class.new(solr_doc_for(updated.id)).outbound).to be_empty
    end
  end

  describe '#inbound' do
    it 'finds works pointing at this one and labels them with the inverse term' do
      relate(from: source, to: target, type: 'source-of')

      inbound = described_class.new(solr_doc_for(target.id)).inbound
      edge = inbound.first

      expect(edge.target_id).to eq(source.id.to_s)
      expect(edge.title).to eq('Source work')
      # source-of stored on the source reads as derived-from on the target
      expect(edge.relation_type).to eq('derived-from')
    end

    it 'is empty for a work nothing points at' do
      expect(described_class.new(solr_doc_for(target.id)).inbound).to be_empty
    end
  end
end
