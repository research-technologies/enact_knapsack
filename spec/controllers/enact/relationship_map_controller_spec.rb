# frozen_string_literal: true

require 'rails_helper'

# Unit coverage for the free-text "other" edge handling added for issue #107.
# The controller's private helpers turn Enact::RelationshipGraph::Edge structs
# into the graph's link keys and legend, so distinct free-text relationship
# types render on the map with their prose rather than collapsing into "Other".
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
