# frozen_string_literal: true

module Enact
  # The works a relationship map is built from, ability-scoped so a work the user may
  # not see never reaches the graph.
  #
  # `portfolio_id` scopes the map to one project (the portfolio plus its member works)
  # so a portfolio's "full diagram linked together" can be shown; without one the
  # whole accessible corpus is used and the caller trims it to connected works.
  class RelationshipMapScope
    # Cap on works pulled into a single map. A project's corpus is small; this is a
    # backstop, surfaced in the response rather than silently truncating.
    MAX_WORKS = 1_000

    def initialize(ability:, portfolio_id: nil)
      @ability = ability
      @portfolio_id = portfolio_id.to_s
    end

    # @return [Enumerable<SolrDocument>]
    def documents
      @documents ||= @portfolio_id.present? ? portfolio_documents : work_documents
    end

    def truncated?
      documents.length >= MAX_WORKS
    end

    private

    # Returns [] if the portfolio is not found / not visible, which renders the
    # empty-map message rather than erroring.
    def portfolio_documents
      portfolio = documents_for_ids([@portfolio_id]).first
      return [] if portfolio.nil?

      ids = ([@portfolio_id] + Array(portfolio['member_ids_ssim'])).uniq.first(MAX_WORKS)
      documents_for_ids(ids)
    end

    # Every work type accessible to the current user. The map pulls the whole set and
    # its caller filters edges to in-set targets (mirrors the prototype); fine for a
    # per-project corpus.
    def work_documents
      models = Hyrax.config.registered_curation_concern_types.presence
      Hyrax::SolrQueryService.new
                             .with_field_pairs(field_pairs: { 'has_model_ssim' => models }, join_with: 'OR')
                             .accessible_by(ability: @ability)
                             .solr_documents(rows: MAX_WORKS)
    end

    def documents_for_ids(ids)
      return [] if ids.blank?

      Hyrax::SolrQueryService.new
                             .with_field_pairs(field_pairs: { 'id' => ids }, join_with: 'OR')
                             .accessible_by(ability: @ability)
                             .solr_documents(rows: MAX_WORKS)
    end
  end
end
