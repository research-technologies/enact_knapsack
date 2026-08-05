# frozen_string_literal: true

module Enact
  # The works a relationship map is built from, ability-scoped so a work the user may
  # not see never reaches the graph. `portfolio_id` narrows it to one project, which is
  # how a portfolio's "full diagram linked together" is drawn.
  #
  # A project reaches one hop past its own membership because its edges are not confined
  # to it (a portfolio can relate to a work in another project, and something outside can
  # point back), and an edge the show page lists but the map cannot draw is how a
  # populated relationship card ends up opening an empty map (issue #161).
  class RelationshipMapScope
    # Cap on works pulled into a single map. A project's corpus is small; this is a
    # backstop, surfaced in the response rather than silently truncating.
    MAX_WORKS = 1_000

    def initialize(ability:, portfolio_id: nil)
      @ability = ability
      @portfolio_id = portfolio_id.to_s
      @truncated = false
    end

    # @return [Enumerable<SolrDocument>]
    def documents
      @documents ||= @portfolio_id.present? ? portfolio_documents : work_documents
    end

    # nil when there is no project boundary for the caller to enforce, and only known
    # once the scope has run.
    # @return [Set<String>, nil]
    def core_ids
      documents
      @core_ids
    end

    # Whether a cap dropped works the graph would otherwise hold, wherever it happened:
    # the project's membership, the one-hop neighbours, or the corpus sweep. Counting the
    # documents that came back cannot answer this, because the caps land on id lists
    # before the ability filter thins them, so a map missing 500 neighbours can still
    # return well under MAX_WORKS.
    def truncated?
      documents
      @truncated
    end

    private

    # Every cap in one place, so none of them can drop works without the view being able
    # to say so.
    def capped(collection)
      @truncated ||= collection.size > MAX_WORKS

      collection.first(MAX_WORKS)
    end

    # Returns [] if the portfolio is not found / not visible, which renders the
    # empty-map message rather than erroring.
    def portfolio_documents
      portfolio = documents_for_ids([@portfolio_id]).first
      return [] if portfolio.nil?

      docs = documents_for_ids(capped(([@portfolio_id] + Array(portfolio['member_ids_ssim'])).uniq))
      # The project as this user can see it, not as it is stored: a member they may not
      # see is not part of the boundary, and reverse-querying for it would pull in the
      # neighbours of a work that can never appear on the map.
      @core_ids = docs.map { |doc| doc['id'] }.to_set
      capped(docs + neighbour_documents(docs))
    end

    # `relationships_item_ssim` is the indexed edge target, the same field the show
    # page's reverse lookup reads.
    def neighbour_documents(docs)
      targets = docs.flat_map { |doc| Array(doc['relationships_item_ssim']) }
                    .reject { |value| Hyrax::CompoundWorkResolver.url?(value) }
      documents_for_ids(capped((targets + inbound_source_ids).uniq - @core_ids.to_a))
    end

    def inbound_source_ids
      Hyrax::SolrQueryService.new
                             .with_field_pairs(field_pairs: { 'relationships_item_ssim' => @core_ids.to_a },
                                               join_with: 'OR')
                             .accessible_by(ability: @ability)
                             .solr_documents(rows: MAX_WORKS, fl: 'id').map { |doc| doc['id'] }
    end

    # The whole set, trimmed to connected works by the caller (mirrors the prototype);
    # affordable while a repository holds one project's corpus per map.
    def work_documents
      models = Hyrax.config.registered_curation_concern_types.presence
      docs = Hyrax::SolrQueryService.new
                                    .with_field_pairs(field_pairs: { 'has_model_ssim' => models }, join_with: 'OR')
                                    .accessible_by(ability: @ability)
                                    .solr_documents(rows: MAX_WORKS)
      # Solr trims to `rows` server-side, so a full page is the only signal left that the
      # corpus holds more.
      @truncated ||= docs.length >= MAX_WORKS

      docs
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
