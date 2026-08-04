# frozen_string_literal: true

require 'rails_helper'

# Mocks the ability-scoped Solr chain (mirrors the Enact::PortfolioTree spec) rather
# than hitting the repo: one index answers the id lookups.
RSpec.describe Enact::RelationshipMapScope do
  let(:ability) { instance_double(Ability) }

  # accessible_by is a no-op here: ability filtering belongs to the real query object
  # and is not re-tested through the fake.
  class FakeMapSolrQuery
    def initialize(index)
      @index = index
      @ids = []
    end

    def with_field_pairs(field_pairs:, **)
      @ids = Array(field_pairs['id'] || field_pairs['has_model_ssim']).map(&:to_s)
      self
    end

    def accessible_by(**)
      self
    end

    def solr_documents(**)
      @ids.filter_map { |id| @index[id] }
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
    let(:index) do
      { 'p1' => doc('p1', members: ['m1']), 'm1' => doc('m1'), 'stranger' => doc('stranger') }
    end

    it 'is the portfolio and its member works when scoped to a project' do
      ids = scope_for(index, portfolio_id: 'p1').documents.map { |d| d['id'] }

      expect(ids).to contain_exactly('p1', 'm1')
    end

    it 'is empty when the portfolio is not visible to this user' do
      expect(scope_for(index, portfolio_id: 'missing').documents).to eq([])
    end
  end
end
