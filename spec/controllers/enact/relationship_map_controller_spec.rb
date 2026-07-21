# frozen_string_literal: true

require 'rails_helper'

# The controller's private helpers turn Edge structs into the map's link keys
# and legend; these cover the free-text "other" edge handling (issue #107).
RSpec.describe Enact::RelationshipMapController do
  let(:edge_class) { Enact::RelationshipGraph::Edge }

  describe '#edge_rel_pair' do
    it 'keys a controlled edge by its authority code (authority supplies the inverse)' do
      edge = edge_class.new(relation_type: 'cites', type_other: nil, type_other_inverse: nil)
      expect(controller.send(:edge_rel_pair, edge)).to eq(['cites', nil])
    end

    it 'keys an "other" edge by its prose so distinct free-text types stay distinct' do
      edge = edge_class.new(relation_type: 'other', type_other: 'Remixes', type_other_inverse: 'Is remixed by')
      expect(controller.send(:edge_rel_pair, edge)).to eq(['Remixes', 'Is remixed by'])
    end

    it 'keys a bare free-text edge by its prose and falls back to it for the inverse' do
      edge = edge_class.new(relation_type: nil, type_other: 'Companion to', type_other_inverse: nil)
      expect(controller.send(:edge_rel_pair, edge)).to eq(['Companion to', 'Companion to'])
    end

    it 'is [nil, nil] for an untyped edge (no controlled type, no prose)' do
      edge = edge_class.new(relation_type: nil, type_other: nil, type_other_inverse: nil)
      expect(controller.send(:edge_rel_pair, edge)).to eq([nil, nil])
    end
  end

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
