# frozen_string_literal: true

require 'rails_helper'

# Mocks the ability-scoped Solr chain (mirrors the Enact::PeopleGraph specs)
# rather than hitting the repo; the fake resolves a doc index by requested id so
# recursion walks a real nested structure.
RSpec.describe Enact::PortfolioTree do
  let(:ability) { instance_double(Ability) }

  # accessible_by is a no-op here: ability filtering belongs to the real query
  # object and is not re-tested through the fake.
  class FakeSolrQuery
    def initialize(index)
      @index = index
    end

    def with_field_pairs(field_pairs:, **)
      @ids = Array(field_pairs['id']).map(&:to_s)
      self
    end

    def accessible_by(**)
      self
    end

    def solr_documents(**)
      @ids.filter_map { |id| @index[id] }
    end
  end

  def doc(id, title:, model: 'PortfolioArtefact', members: [])
    SolrDocument.new('id' => id, 'title_tesim' => [title],
                     'has_model_ssim' => [model], 'member_ids_ssim' => members)
  end

  # A fresh fake per #new keeps each query's captured ids isolated across the
  # recursion's many queries.
  def tree_for(index, root_id, **opts)
    allow(Hyrax::SolrQueryService).to receive(:new) { FakeSolrQuery.new(index) }
    described_class.new(ability:, **opts).for_work(root_id)
  end

  describe '#for_work' do
    let(:index) do
      {
        'p1' => doc('p1', title: 'A Machine for Learning', model: 'Portfolio', members: %w[a1 c1]),
        'a1' => doc('a1', title: 'Scale model'),
        'c1' => doc('c1', title: 'Documentation media', model: 'PortfolioItemCollection', members: %w[g1]),
        'g1' => doc('g1', title: 'Photographic record', model: 'PortfolioArtefact')
      }
    end

    it 'builds the nested composition tree from member_ids' do
      root = tree_for(index, 'p1')

      expect(root.label).to eq('A Machine for Learning')
      expect(root.type).to eq('portfolio')
      expect(root.children.map(&:label)).to contain_exactly('Scale model', 'Documentation media')

      collection = root.children.find { |n| n.type == 'collection' }
      expect(collection.children.map(&:label)).to eq(['Photographic record'])
    end

    it 'maps work types to a badge key and human label' do
      artefact = tree_for(index, 'p1').children.find { |n| n.label == 'Scale model' }

      expect(artefact.type).to eq('artefact')
      expect(artefact.type_label).to eq('Artefact')
      expect(artefact.path).to eq('/concern/portfolio_artefacts/a1')
      expect(artefact.children?).to be(false)
    end

    it 'returns nil when the work is not found or not readable' do
      expect(tree_for(index, 'missing')).to be_nil
    end

    it 'builds the full tree when the same instance is reused' do
      allow(Hyrax::SolrQueryService).to receive(:new) { FakeSolrQuery.new(index) }
      service = described_class.new(ability:)

      first = service.for_work('p1')
      second = service.for_work('p1')

      expect(second.children.map(&:label)).to eq(first.children.map(&:label))
    end

    it 'stops recursing at the depth cap' do
      root = tree_for(index, 'p1', max_depth: 1)
      collection = root.children.find { |n| n.type == 'collection' }

      # level 1 (the collection) is present; its level-2 members are not walked
      expect(collection.children).to be_empty
    end

    it 'guards against a membership cycle' do
      cyclic = {
        'p1' => doc('p1', title: 'Root', model: 'Portfolio', members: %w[a1]),
        'a1' => doc('a1', title: 'Child', members: %w[p1]) # points back at the root
      }

      root = tree_for(cyclic, 'p1')
      expect(root.children.first.children).to be_empty
    end
  end

  describe '#for_deposit' do
    let(:index) do
      {
        'p1' => doc('p1', title: 'A Machine for Learning', model: 'Portfolio', members: %w[a1]),
        'a1' => doc('a1', title: 'Existing artefact')
      }
    end

    def deposit(index, parent_id:, pending:)
      allow(Hyrax::SolrQueryService).to receive(:new) { FakeSolrQuery.new(index) }
      described_class.new(ability:).for_deposit(parent_id:, pending:)
    end

    it 'stamps saved works existing and appends the pending item as a new leaf' do
      root = deposit(index, parent_id: 'p1',
                            pending: { label: 'Unveiling event', type: 'PortfolioEvent' })

      expect(root.status).to eq('existing')
      expect(root.children.map(&:status)).to eq(%w[existing new])

      pending = root.children.last
      expect(pending.label).to eq('Unveiling event')
      expect(pending.type).to eq('event')
      expect(pending.type_label).to eq('Event')
      expect(pending.id).to be_nil
      expect(pending.path).to be_nil
    end

    it 'returns nil when there is no target portfolio' do
      expect(deposit(index, parent_id: '', pending: { label: 'x', type: 'PortfolioArtefact' })).to be_nil
    end

    it 'is type-agnostic: builds a tree rooted at a non-portfolio parent' do
      collection_index = {
        'c9' => doc('c9', title: 'Documentation media', model: 'PortfolioItemCollection', members: %w[a9]),
        'a9' => doc('a9', title: 'Existing photo')
      }

      root = deposit(collection_index, parent_id: 'c9',
                                       pending: { label: 'New clip', type: 'PortfolioArtefact' })

      # The heading reads from type_label, so a Collection root labels itself.
      expect(root.type_label).to eq('Collection')
      expect(root.children.map(&:status)).to eq(%w[existing new])
    end
  end
end
