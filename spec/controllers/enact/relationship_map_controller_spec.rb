# frozen_string_literal: true

require 'rails_helper'

# The labelling rules live on Enact::RelationshipGraph::Edge and which works are in
# scope on Enact::RelationshipMapScope; both are specced there.
RSpec.describe Enact::RelationshipMapController do
  let(:edge_class) { Enact::RelationshipGraph::Edge }

  describe '#links_for' do
    def graph_of(*edges)
      allow(Enact::RelationshipGraph).to receive(:new)
        .and_return(instance_double(Enact::RelationshipGraph, outbound: edges))
    end

    it 'drops an untyped edge so the map never emits a null-typed link' do
      graph_of(edge_class.new(target_id: 't1', relation_type: nil, type_other: nil, type_other_inverse: nil))
      expect(controller.send(:links_for, { 'id' => 's1' })).to be_empty
    end

    it 'keeps a free-text "other" edge keyed by its prose' do
      graph_of(edge_class.new(target_id: 't1', relation_type: 'other',
                              type_other: 'Remixes', type_other_inverse: 'Is remixed by'))
      link = controller.send(:links_for, { 'id' => 's1' }).first
      expect(link).to include(source: 's1', target: 't1', rel: 'Remixes', rel_inverse: 'Is remixed by')
    end
  end

  describe '#kept_links' do
    let(:docs) { [{ 'id' => 'core' }, { 'id' => 'n1' }, { 'id' => 'n2' }] }
    let(:links) do
      { 'core' => [{ source: 'core', target: 'n1', rel: 'cites' }],
        'n1' => [{ source: 'n1', target: 'n2', rel: 'cites' }],
        'n2' => [{ source: 'n2', target: 'core', rel: 'cites' }] }
    end

    before { allow(controller).to receive(:links_for) { |doc| links[doc['id']] } }

    it 'keeps only the edges touching the project when scoped to a portfolio' do
      expect(controller.send(:kept_links, docs, Set['core'])).to contain_exactly(
        hash_including(source: 'core', target: 'n1'),
        hash_including(source: 'n2', target: 'core')
      )
    end

    it 'keeps every edge between in-scope works when not scoped to a portfolio' do
      expect(controller.send(:kept_links, docs, nil).size).to eq(3)
    end

    it 'keeps an external URL target, which is never in the document set' do
      allow(controller).to receive(:links_for) do |doc|
        next [] unless doc['id'] == 'core'
        [{ source: 'core', target: 'https://example.org/a', rel: 'cites', external: true }]
      end

      expect(controller.send(:kept_links, docs, Set['core']).map { |l| l[:target] })
        .to eq(['https://example.org/a'])
    end
  end

  describe '#rel_types' do
    it 'builds a controlled legend entry from the authority' do
      links = [{ rel: 'cites', rel_inverse: nil }]
      entry = controller.send(:rel_types, links)['cites']

      expect(entry[:label]).to eq('Cites')
      expect(entry[:inverse]).to eq('Is Cited By')
      expect(entry[:color]).to eq(Enact::RelationshipTypesService.color('cites'))
    end

    it 'builds a free-text legend entry shown verbatim with its inverse prose' do
      links = [{ rel: 'Remixes', rel_inverse: 'Is remixed by' }]
      entry = controller.send(:rel_types, links)['Remixes']

      expect(entry[:label]).to eq('Remixes')
      expect(entry[:inverse]).to eq('Is remixed by')
      expect(entry[:color]).to eq(Enact::RelationshipTypesService::FALLBACK_COLOR)
      expect(entry[:dc]).to be_nil
    end

    it 'falls back to the forward prose when no inverse is supplied' do
      links = [{ rel: 'Companion to', rel_inverse: nil }]
      expect(controller.send(:rel_types, links)['Companion to'][:inverse]).to eq('Companion to')
    end
  end
end
