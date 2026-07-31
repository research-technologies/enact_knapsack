# frozen_string_literal: true

require 'rails_helper'

# Mocks the ability-scoped Solr chain (mirrors the Enact::PeopleGraph specs)
# rather than hitting the repo; the fake resolves a doc index by requested id so
# recursion walks a real nested structure.
RSpec.describe Enact::PortfolioTree do
  let(:ability) { instance_double(Ability) }

  # Path derivation is delegated to the shared Hyrax::CompoundWorkResolver (route
  # helpers, collection handling, unroutable fallback), which is tested in Hyrax.
  # Here we only assert PortfolioTree hands it the right id, so stub it to echo one.
  before { allow(Hyrax::CompoundWorkResolver).to receive(:path_for) { |id, **| "/resolved/#{id}" } }

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

    # Guards the render-perf fix (#95): each node's path is resolved from the doc
    # already fetched in the batch, not by re-querying Solr per node.
    it 'resolves node paths from the already-fetched doc, not a per-node re-query' do
      tree_for(index, 'p1')

      expect(Hyrax::CompoundWorkResolver).to have_received(:path_for)
        .with('a1', doc: an_instance_of(SolrDocument))
    end

    it 'maps work types to a badge key and human label' do
      artefact = tree_for(index, 'p1').children.find { |n| n.label == 'Scale model' }

      expect(artefact.type).to eq('artefact')
      expect(artefact.type_label).to eq('Artefact')
      expect(artefact.path).to eq('/resolved/a1')
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

    it 'enforces MAX_NODES as a hard ceiling, stopping mid-level' do
      # Root plus three direct members; capped at 2 total nodes means the root
      # plus exactly one member, and no more siblings built at that level.
      wide = {
        'p1' => doc('p1', title: 'Root', model: 'Portfolio', members: %w[a1 a2 a3]),
        'a1' => doc('a1', title: 'One'),
        'a2' => doc('a2', title: 'Two'),
        'a3' => doc('a3', title: 'Three')
      }

      root = tree_for(wide, 'p1', max_nodes: 2)
      expect(root.children.size).to eq(1)
    end

    it 'guards against a membership cycle' do
      cyclic = {
        'p1' => doc('p1', title: 'Root', model: 'Portfolio', members: %w[c1]),
        # A container that points back at the root; without the visited guard this
        # would recurse forever.
        'c1' => doc('c1', title: 'Child', model: 'PortfolioItemCollection', members: %w[p1])
      }

      root = tree_for(cyclic, 'p1')
      expect(root.children.first.children).to be_empty
    end

    it 'does not descend into leaf item types (their members are only FileSets)' do
      with_file = {
        'p1' => doc('p1', title: 'Root', model: 'Portfolio', members: %w[a1]),
        'a1' => doc('a1', title: 'Scale model', model: 'PortfolioArtefact', members: %w[fs1]),
        'fs1' => doc('fs1', title: 'scan.tif', model: 'Hyrax::FileSet')
      }
      allow(Hyrax::SolrQueryService).to receive(:new) { FakeSolrQuery.new(with_file) }

      artefact = described_class.new(ability:).for_work('p1').children.first

      expect(artefact.label).to eq('Scale model')
      expect(artefact.children).to be_empty
      # Only the root doc + the root's members are fetched; the leaf artefact's
      # members (its FileSet) are never queried - the render-perf fix (#95).
      expect(Hyrax::SolrQueryService).to have_received(:new).twice
    end

    it 'drops non-work members (FileSets) rather than rendering them as nodes' do
      mixed = {
        'p1' => doc('p1', title: 'Root', model: 'Portfolio', members: %w[a1 cover]),
        'a1' => doc('a1', title: 'Scale model', model: 'PortfolioArtefact'),
        'cover' => doc('cover', title: 'cover.jpg', model: 'Hyrax::FileSet')
      }

      root = tree_for(mixed, 'p1')

      expect(root.children.map(&:label)).to eq(['Scale model'])
    end
  end

  describe '#for_completed_deposit' do
    let(:index) do
      {
        'p1' => doc('p1', title: 'A Machine for Learning', model: 'Portfolio', members: %w[a1 e1]),
        'a1' => doc('a1', title: 'Existing artefact'),
        'e1' => doc('e1', title: 'Unveiling event', model: 'PortfolioEvent')
      }
    end

    def completed(index, parent_id:, work_id:)
      allow(Hyrax::SolrQueryService).to receive(:new) { FakeSolrQuery.new(index) }
      described_class.new(ability:).for_completed_deposit(parent_id:, work_id:)
    end

    it 'stamps every saved work existing except the just-deposited one, stamped new' do
      root = completed(index, parent_id: 'p1', work_id: 'e1')

      expect(root.status).to eq('existing')

      new_node = root.children.find { |n| n.label == 'Unveiling event' }
      existing_node = root.children.find { |n| n.label == 'Existing artefact' }
      expect(new_node.status).to eq('new')
      expect(existing_node.status).to eq('existing')

      # Unlike the old pending node, the new item is a real saved work with a link.
      expect(new_node.id).to eq('e1')
      expect(new_node.path).to eq('/resolved/e1')
    end

    it 'marks a work nested inside a collection item, not just a direct member' do
      nested = {
        'p1' => doc('p1', title: 'Root', model: 'Portfolio', members: %w[c1]),
        'c1' => doc('c1', title: 'Documentation media', model: 'PortfolioItemCollection', members: %w[g1]),
        'g1' => doc('g1', title: 'Photographic record')
      }

      root = completed(nested, parent_id: 'p1', work_id: 'g1')
      collection = root.children.find { |n| n.type == 'collection' }

      expect(collection.status).to eq('existing')
      expect(collection.children.first.status).to eq('new')
    end

    it 'returns nil when there is no target portfolio' do
      expect(completed(index, parent_id: '', work_id: 'a1')).to be_nil
    end

    it 'is type-agnostic: builds a tree rooted at a non-portfolio parent' do
      collection_index = {
        'c9' => doc('c9', title: 'Documentation media', model: 'PortfolioItemCollection', members: %w[a9 a10]),
        'a9' => doc('a9', title: 'Existing photo'),
        'a10' => doc('a10', title: 'New clip')
      }

      root = completed(collection_index, parent_id: 'c9', work_id: 'a10')

      # The heading reads from type_label, so a Collection root labels itself.
      expect(root.type_label).to eq('Collection')
      expect(root.children.find { |n| n.label == 'New clip' }.status).to eq('new')
      expect(root.children.find { |n| n.label == 'Existing photo' }.status).to eq('existing')
    end
  end
end
