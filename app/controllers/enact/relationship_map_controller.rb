# frozen_string_literal: true

module Enact
  # Read-only interactive relationship map (the "patch cables", Object Handling
  # Spec v0.2 Sec 3.5). Ported from the Hyrax prototype branch
  # `wip-enact-relationship-map` onto PR #32's real relationship data: nodes are
  # works, edges are the typed `relationships` compound read through
  # Enact::RelationshipGraph. `?focus=<work id>` centres the graph on one work,
  # which is how the "Relationship map" button on a work's relationship card
  # opens it.
  #
  # Knapsack-local custom code; deliberately NOT contributed to Hyrax yet (the
  # production design is a first-class relationship model + deposit UI, still in
  # co-design). The view renders with `layout: false`.
  class RelationshipMapController < ApplicationController
    # Presentation-only metadata for the six controlled relation terms
    # (m3 profile `relationship_type`). Human labels come from the locale files
    # (`enact.relationships.types.*`); colour + DataCite mapping live here
    # because they are pure view concerns.
    REL_COLOR = {
      'sequence' => '#5b9bd5', 'source-of' => '#c0823c', 'pair-with' => '#b05ec0',
      'response-to' => '#c9544b', 'documents' => '#4aa3a3', 'juxtaposed-with' => '#c2a83e'
    }.freeze
    REL_DATACITE = {
      'sequence' => 'IsContinuedBy / Continues', 'source-of' => 'IsSourceOf / IsDerivedFrom',
      'pair-with' => 'IsVariantFormOf', 'response-to' => 'References / IsReferencedBy',
      'documents' => 'Documents / IsDocumentedBy', 'juxtaposed-with' => 'IsRelatedMaterial'
    }.freeze

    # Cap on works pulled into a single map. A project's corpus is small; this
    # is a backstop, surfaced in the response rather than silently truncating.
    MAX_WORKS = 1_000

    def show
      docs = work_documents
      ids = docs.map { |d| d['id'] }.to_set
      @graph = {
        nodes: docs.map { |d| node_for(d) },
        links: docs.flat_map { |d| links_for(d) }.select { |l| ids.include?(l[:target]) }
      }
      @rel_types = rel_types
      @focus = params[:focus].to_s
      @truncated = docs.length >= MAX_WORKS
      render layout: false
    end

    private

    # Enact work types accessible to the current user. We pull the whole set and
    # filter edges to in-set targets (mirrors the prototype); fine for a
    # per-project corpus.
    def work_documents
      models = Hyrax.config.registered_curation_concern_types.presence
      Hyrax::SolrQueryService.new
                             .with_field_pairs(field_pairs: { 'has_model_ssim' => models }, join_with: 'OR')
                             .accessible_by(ability: current_ability)
                             .solr_documents(rows: MAX_WORKS)
    end

    def node_for(doc)
      model = Array(doc['has_model_ssim']).first.to_s
      {
        id: doc['id'],
        label: Array(doc['title_tesim']).first || 'Untitled',
        type: model,
        date: Array(doc['date_created_tesim']).first,
        keywords: Array(doc['keyword_tesim']),
        description: Array(doc['description_tesim']).first,
        thumb: thumbnail_url(doc),
        closed: doc['visibility_ssi'] == 'restricted',
        path: model.present? ? "/concern/#{model.tableize}/#{doc['id']}" : "/#{doc['id']}"
      }
    end

    # Only a real string URL is usable as a Cytoscape `background-image`;
    # thumbnail_path can return a non-string (or a default placeholder), which
    # would otherwise stringify to "[object Object]" and 404.
    def thumbnail_url(solr_doc)
      path = solr_doc.thumbnail_path
      path if path.is_a?(::String) && path.present?
    end

    # Outbound edges this work declares, via the #32 relationship reader.
    #
    # NOTE: `doc` is already a ::SolrDocument (SolrQueryService#solr_documents
    # instantiates them). Wrapping a SolrDocument in another SolrDocument breaks
    # `#[]` field access, which silently empties every edge list - so pass the
    # document through as-is.
    def links_for(doc)
      ::Enact::RelationshipGraph.new(doc).outbound.map do |edge|
        { source: doc['id'], target: edge.target_id, rel: edge.relation_type,
          note: edge.note, position: edge.position }
      end
    end

    # term => { label, inverse, color, dc } for the legend and edge labels.
    # `inverse` reads the edge from the target's point of view (same locale
    # entries the relationships card uses for inbound edges).
    def rel_types
      REL_COLOR.keys.index_with do |term|
        inverse_term = ::Enact::RelationshipGraph::INVERSE_OF.fetch(term, term)
        { label: t("enact.relationships.types.#{term}", default: term.tr('-', ' ')),
          inverse: t("enact.relationships.inverse_types.#{inverse_term}", default: inverse_term.tr('-', ' ')),
          color: REL_COLOR[term],
          dc: REL_DATACITE[term] }
      end
    end
  end
end
