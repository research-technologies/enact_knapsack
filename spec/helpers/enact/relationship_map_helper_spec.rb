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

  # Visibility is no longer this gate's question: the graph filters withheld targets
  # and sources itself (issue #182, covered in the RelationshipGraph spec), so any
  # edge that arrives here is openable and only typedness decides.
  describe '#enact_relationship_map?' do
    it 'is false with no edges at all' do
      edges
      expect(helper.enact_relationship_map?(presenter)).to be(false)
    end

    it 'is false when the only edge is untyped, which the map would not draw' do
      edges(outbound: [edge_class.new(target_id: 'target', relation_type: nil, type_other: nil)])
      expect(helper.enact_relationship_map?(presenter)).to be(false)
    end

    it 'is true for a typed external URL target' do
      edges(outbound: [typed_edge(target_id: 'https://example.org/a', external: true)])
      expect(helper.enact_relationship_map?(presenter)).to be(true)
    end

    it 'is true for a typed edge to a work' do
      edges(outbound: [typed_edge])
      expect(helper.enact_relationship_map?(presenter)).to be(true)
    end

    it 'counts inbound edges too, so a work that is only a target gets a map' do
      edges(inbound: [typed_edge(target_id: 'source')])
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
    let(:ability) { instance_double(Ability) }
    let(:graph) { instance_double(Enact::RelationshipGraph, outbound: [], inbound: []) }

    before { allow(helper).to receive(:current_ability).and_return(ability) }

    it 'builds the graph once per work and reuses both directions' do
      expect(Enact::RelationshipGraph).to receive(:new).once.and_return(graph)

      2.times { helper.enact_relationship_edges(presenter) }
    end

    it 'passes the viewer ability so withheld targets never reach the card (issue #182)' do
      expect(Enact::RelationshipGraph).to receive(:new)
        .with(presenter.solr_document, ability:).and_return(graph)

      helper.enact_relationship_edges(presenter)
    end
  end
end
