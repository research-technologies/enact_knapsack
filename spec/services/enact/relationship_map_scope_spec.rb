# frozen_string_literal: true

require 'rails_helper'

# Mocks the ability-scoped Solr chain (mirrors the Enact::PortfolioTree spec) rather
# than hitting the repo: one index answers both the id lookups and the reverse lookup
# on `relationships_item_ssim`.
RSpec.describe Enact::RelationshipMapScope do
  let(:ability) { instance_double(Ability) }

  # accessible_by is a no-op here: ability filtering belongs to the real query object
  # and is not re-tested through the fake.
  class FakeMapSolrQuery
    def initialize(index)
      @index = index
      @ids = []
      @targets = []
    end

    def with_field_pairs(field_pairs:, **)
      @ids = Array(field_pairs['id'] || field_pairs['has_model_ssim']).map(&:to_s)
      @targets = Array(field_pairs['relationships_item_ssim']).map(&:to_s)
      self
    end

    def accessible_by(**)
      self
    end

    # A reverse lookup answers with the docs whose edges point at the requested ids;
    # an id lookup answers with the requested docs themselves.
    def solr_documents(**)
      return sources_pointing_at_targets if @targets.any?

      @ids.filter_map { |id| @index[id] }
    end

    private

    def sources_pointing_at_targets
      @index.values.select { |doc| (Array(doc['relationships_item_ssim']) & @targets).any? }
    end
  end

  def doc(id, members: [], relates_to: [])
    SolrDocument.new('id' => id, 'title_tesim' => ["Work #{id}"], 'has_model_ssim' => ['Portfolio'],
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
  end

  describe '#core_ids' do
    let(:index) { { 'p1' => doc('p1', members: %w[m1]), 'm1' => doc('m1') } }

    it 'is the project itself, so a caller can tell a project edge from a neighbour\'s' do
      expect(scope_for(index, portfolio_id: 'p1').core_ids).to eq(Set['p1', 'm1'])
    end

    it 'is nil without a portfolio: the whole corpus has no project boundary' do
      expect(scope_for(index).core_ids).to be_nil
    end
  end
end
