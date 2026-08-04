# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Enact::RelationshipMapHelper, type: :helper do
  let(:edge_class) { Enact::RelationshipGraph::Edge }
  let(:presenter) { double('presenter', id: 'abc', solr_document: { 'has_model_ssim' => ['PortfolioArtefact'] }) }

  def edges(outbound: [], inbound: [])
    allow(helper).to receive(:enact_relationship_edges).with(presenter)
                                                       .and_return(outbound:, inbound:)
  end

  def typed_edge(target_id: 'target', external: false)
    edge_class.new(target_id:, relation_type: 'cites', external:)
  end

  describe '#enact_relationship_map?' do
    it 'is false with no edges at all' do
      edges
      expect(helper.enact_relationship_map?(presenter)).to be(false)
    end

    it 'is false when the only edge is untyped, which the map would not draw' do
      edges(outbound: [edge_class.new(target_id: 'target', relation_type: nil, type_other: nil)])
      expect(helper.enact_relationship_map?(presenter)).to be(false)
    end

    it 'is true for an external URL target without asking Solr' do
      edges(outbound: [typed_edge(target_id: 'https://example.org/a', external: true)])
      expect(helper).not_to receive(:enact_visible_work?)

      expect(helper.enact_relationship_map?(presenter)).to be(true)
    end

    it 'is true when a typed edge points at a work this user can see' do
      edges(outbound: [typed_edge])
      allow(helper).to receive(:enact_visible_work?).with(['target']).and_return(true)

      expect(helper.enact_relationship_map?(presenter)).to be(true)
    end

    # The card resolves targets without an ability check, so a listed relationship is
    # not proof of a non-empty map (issue #161).
    it 'is false when the target resolves for the card but is not visible to this user' do
      edges(outbound: [typed_edge])
      allow(helper).to receive(:enact_visible_work?).and_return(false)

      expect(helper.enact_relationship_map?(presenter)).to be(false)
    end

    it 'counts inbound edges too, so a work that is only a target gets a map' do
      edges(inbound: [typed_edge(target_id: 'source')])
      allow(helper).to receive(:enact_visible_work?).with(['source']).and_return(true)

      expect(helper.enact_relationship_map?(presenter)).to be(true)
    end

    it 'is false rather than raising when the edges cannot be read' do
      allow(helper).to receive(:enact_relationship_edges).and_raise(StandardError, 'solr down')
      expect(helper.enact_relationship_map?(presenter)).to be(false)
    end
  end

  describe '#enact_relationship_map_trigger' do
    it 'renders a modal trigger when the map has something to draw' do
      allow(helper).to receive(:enact_relationship_map?).with(presenter).and_return(true)
      html = helper.enact_relationship_map_trigger(presenter)

      expect(html).to include('data-map-url="/relationship-map?focus=abc"')
      expect(html).to include('aria-controls="enactMapModal"')
    end

    it 'renders nothing when the map would open empty' do
      allow(helper).to receive(:enact_relationship_map?).with(presenter).and_return(false)
      expect(helper.enact_relationship_map_trigger(presenter)).to eq('')
    end

    it 'lets the theme pass its own button class' do
      allow(helper).to receive(:enact_relationship_map?).and_return(true)
      html = helper.enact_relationship_map_trigger(presenter, html_class: 'btn btn-primary btn-sm')

      expect(html).to include('class="btn btn-primary btn-sm"')
    end
  end

  describe '#enact_relationship_map_path' do
    def path_for(model)
      presenter = double('presenter', id: 'abc', solr_document: { 'has_model_ssim' => [model] })
      helper.enact_relationship_map_path(presenter)
    end

    it 'opens the whole-project diagram for a Portfolio' do
      expect(path_for('Portfolio')).to end_with('?portfolio=abc')
    end

    it 'focuses the map on any other work type' do
      expect(path_for('PortfolioArtefact')).to end_with('?focus=abc')
    end
  end

  describe '#enact_relationship_edges' do
    it 'builds the graph once per work and reuses both directions' do
      graph = instance_double(Enact::RelationshipGraph, outbound: [], inbound: [])
      expect(Enact::RelationshipGraph).to receive(:new).once.and_return(graph)

      2.times { helper.enact_relationship_edges(presenter) }
    end
  end
end
