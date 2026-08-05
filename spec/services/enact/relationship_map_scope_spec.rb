# frozen_string_literal: true

require 'rails_helper'

# Mocks the ability-scoped Solr chain (mirrors the Enact::PortfolioTree spec) rather
# than hitting the repo: one index answers both the id lookups and the reverse lookup
# on `relationships_item_ssim`.
RSpec.describe Enact::RelationshipMapScope do
  let(:ability) { instance_double(Ability) }

  # accessible_by is a no-op here: ability filtering belongs to the real query object
  # and is not re-tested through the fake.
  # Each query field is tracked on its own so every branch of the scope is answerable:
  # id lookups, the has_model_ssim sweep behind an unscoped map, and the reverse lookup
  # on relationships_item_ssim.
  class FakeMapSolrQuery
    def initialize(index)
      @index = index
      @ids = []
      @models = []
      @targets = []
    end

    def with_field_pairs(field_pairs:, **)
      @ids = Array(field_pairs['id']).map(&:to_s)
      @models = Array(field_pairs['has_model_ssim']).map(&:to_s)
      @targets = Array(field_pairs['relationships_item_ssim']).map(&:to_s)
      self
    end

    def accessible_by(**)
      self
    end

    def solr_documents(**)
      return sources_pointing_at_targets if @targets.any?
      return docs_of_models if @models.any?

      @ids.filter_map { |id| @index[id] }
    end

    private

    def sources_pointing_at_targets
      @index.values.select { |doc| (Array(doc['relationships_item_ssim']) & @targets).any? }
    end

    def docs_of_models
      @index.values.select { |doc| (Array(doc['has_model_ssim']) & @models).any? }
    end
  end

  def doc(id, members: [], relates_to: [], model: 'Portfolio')
    SolrDocument.new('id' => id, 'title_tesim' => ["Work #{id}"], 'has_model_ssim' => [model],
                     'member_ids_ssim' => members, 'relationships_item_ssim' => relates_to)
  end

  def scope_for(index, portfolio_id: nil)
    allow(Hyrax::SolrQueryService).to receive(:new) { FakeMapSolrQuery.new(index) }
    described_class.new(ability:, portfolio_id:)
  end

  describe '#documents' do
    # The project (p1 + its member m1), an outside work m1 points at, an outside work
    # pointing back in, and a work with no connection to the project at all.
    let(:index) do
      { 'p1' => doc('p1', members: ['m1']),
        'm1' => doc('m1', relates_to: ['outward']),
        'outward' => doc('outward'),
        'inward' => doc('inward', relates_to: ['p1']),
        'stranger' => doc('stranger', relates_to: ['other']) }
    end

    it 'is the portfolio, its members, and the works one hop out either way (#161)' do
      ids = scope_for(index, portfolio_id: 'p1').documents.map { |d| d['id'] }

      expect(ids).to contain_exactly('p1', 'm1', 'outward', 'inward')
    end

    it 'is empty when the portfolio is not visible to this user' do
      expect(scope_for(index, portfolio_id: 'missing').documents).to eq([])
    end

    it 'skips an external URL target, which is not a work to fetch' do
      index['m1'] = doc('m1', relates_to: ['https://example.org/a'])
      ids = scope_for(index, portfolio_id: 'p1').documents.map { |d| d['id'] }

      expect(ids).to contain_exactly('p1', 'm1', 'inward')
    end

    it 'is every accessible work of a registered type when no project is named' do
      ids = scope_for(index).documents.map { |d| d['id'] }

      expect(ids).to contain_exactly('p1', 'm1', 'outward', 'inward', 'stranger')
    end

    # A member this user cannot see is not in the project as far as the map is
    # concerned, so it neither draws nor drags its own neighbours in (issue #161).
    # `lurker` points at the withheld member and at nothing else in the project.
    it 'leaves out a member the ability filter withholds, and that member\'s neighbours' do
      index['p1'] = doc('p1', members: %w[m1 hidden])
      index['lurker'] = doc('lurker', relates_to: ['hidden'])
      ids = scope_for(index, portfolio_id: 'p1').documents.map { |d| d['id'] }

      expect(ids).to contain_exactly('p1', 'm1', 'outward', 'inward')
    end
  end

  # MAX_WORKS is stubbed down so the fixtures stay readable; the cap's value is not what
  # these examples are about.
  describe '#truncated?' do
    it 'is false when no cap dropped anything' do
      index = { 'p1' => doc('p1', members: %w[m1]), 'm1' => doc('m1') }
      stub_const('Enact::RelationshipMapScope::MAX_WORKS', 5)

      expect(scope_for(index, portfolio_id: 'p1')).not_to be_truncated
    end

    it 'is true when the project holds more members than the cap allows' do
      index = { 'p1' => doc('p1', members: %w[m1 m2 m3]), 'm1' => doc('m1'),
                'm2' => doc('m2'), 'm3' => doc('m3') }
      stub_const('Enact::RelationshipMapScope::MAX_WORKS', 2)

      expect(scope_for(index, portfolio_id: 'p1')).to be_truncated
    end

    # The case counting the returned documents cannot see: the cap lands on the neighbour
    # id list, and the ability filter then withholds most of what survived, so the map
    # comes back far under the cap while still missing works.
    it 'is true when neighbours were dropped, even though fewer works came back than the cap' do
      index = { 'p1' => doc('p1', relates_to: %w[n1 n2 n3 n4]) }
      stub_const('Enact::RelationshipMapScope::MAX_WORKS', 3)
      scope = scope_for(index, portfolio_id: 'p1')

      expect(scope.documents.size).to eq(1)
      expect(scope).to be_truncated
    end

    it 'is true when the corpus sweep comes back full, since Solr trims the rest' do
      index = { 'a' => doc('a'), 'b' => doc('b') }
      stub_const('Enact::RelationshipMapScope::MAX_WORKS', 2)

      expect(scope_for(index)).to be_truncated
    end
  end

  describe '#core_ids' do
    let(:index) { { 'p1' => doc('p1', members: %w[m1]), 'm1' => doc('m1') } }

    it 'is the project itself, so a caller can tell a project edge from a neighbour\'s' do
      expect(scope_for(index, portfolio_id: 'p1').core_ids).to eq(Set['p1', 'm1'])
    end

    it 'holds only the members this user can see' do
      index['p1'] = doc('p1', members: %w[m1 hidden])

      expect(scope_for(index, portfolio_id: 'p1').core_ids).to eq(Set['p1', 'm1'])
    end

    it 'is nil without a portfolio: the whole corpus has no project boundary' do
      expect(scope_for(index).core_ids).to be_nil
    end
  end
end
