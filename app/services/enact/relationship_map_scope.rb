# frozen_string_literal: true

module Enact
  # The works a relationship map is built from, ability-scoped so a work the user may
  # not see never reaches the graph.
  #
  # `portfolio_id` scopes the map to one project: the portfolio, its member works, and
  # one hop out to the works the project's relationships actually reach. A project's
  # edges are not confined to its membership (a portfolio can relate to a work in
  # another project, and something outside can point back), and an edge the show page
  # lists but the map cannot draw is how a populated relationship card ends up opening
  # an empty map (issue #161).
  #
  # Without a portfolio the whole accessible corpus is used and {#core_ids} is nil,
  # meaning "no project boundary".
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

    # The project's own works, or nil when the map is not scoped to a project.
    # Callers use it to tell a project edge from a neighbour's own edge.
    # @return [Set<String>, nil]
    def core_ids
      documents
      @core_ids
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

      @core_ids = ([@portfolio_id] + Array(portfolio['member_ids_ssim'])).uniq.first(MAX_WORKS).to_set
      docs = documents_for_ids(@core_ids.to_a)
      (docs + neighbour_documents(docs)).first(MAX_WORKS)
    end

    # Works one hop outside the project: the targets of in-project edges, plus the
    # sources whose edges point back in (`relationships_item_ssim` is the indexed
    # target id, the same field the show page's reverse lookup uses).
    def neighbour_documents(docs)
      targets = docs.flat_map { |doc| Array(doc['relationships_item_ssim']) }
                    .reject { |value| Hyrax::CompoundWorkResolver.url?(value) }
      ids = ((targets + inbound_source_ids).uniq - @core_ids.to_a).first(MAX_WORKS)

      documents_for_ids(ids)
    end

    def inbound_source_ids
      Hyrax::SolrQueryService.new
                             .with_field_pairs(field_pairs: { 'relationships_item_ssim' => @core_ids.to_a },
                                               join_with: 'OR')
                             .accessible_by(ability: @ability)
                             .solr_documents(rows: MAX_WORKS, fl: 'id').map { |doc| doc['id'] }
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
