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
    include ::Enact::RequiresRelationshipsCompound

    # Cap on works pulled into a single map. A project's corpus is small; this
    # is a backstop, surfaced in the response rather than silently truncating.
    MAX_WORKS = 1_000

    # Opt-in gate: the map only works when the tenant's metadata profile declares
    # the `relationships` compound (see docs/relationship-map-setup.md). Without
    # it there is nothing to draw, so the standalone page 404s rather than showing
    # an empty graph. The in-page "Relationship map" button is already implicitly
    # gated - it renders only inside the relationships compound card, which the
    # profile drives.
    before_action :require_relationships_compound, only: :show

    def show
      docs = scoped_documents
      links = kept_links(docs)
      @graph = { nodes: graph_nodes(docs, links), links: }
      @rel_types = rel_types(links)
      @focus = params[:focus].to_s
      @truncated = docs.length >= MAX_WORKS
      render layout: false
    end

    private

    # Edges kept for the graph: those to in-project works (the work-to-work web,
    # Object Handling Spec v0.2 Sec 3.5) plus those to external URLs (work_or_url
    # targets outside the repository), which render as their own link nodes.
    def kept_links(docs)
      ids = docs.map { |d| d['id'] }.to_set
      docs.flat_map { |d| links_for(d) }.select { |l| ids.include?(l[:target]) || l[:external] }
    end

    # Nodes for the graph: connected works (a work survives iff it is on a kept
    # edge, so unconnected works are dropped) plus a link node per external URL.
    def graph_nodes(docs, links)
      connected = links.flat_map { |l| [l[:source], l[:target]] }.to_set
      work_nodes = docs.select { |d| connected.include?(d['id']) }.map { |d| node_for(d) }
      url_nodes = links.select { |l| l[:external] }.map { |l| l[:target] }.uniq.map { |u| url_node_for(u) }
      work_nodes + url_nodes
    end

    # The works the map is built from. `?portfolio=<id>` scopes to a single
    # project (the portfolio plus its member works) so a portfolio's "full
    # diagram linked together" can be shown; otherwise the whole accessible
    # corpus is used (then trimmed to connected works in #show).
    def scoped_documents
      portfolio_id = params[:portfolio].to_s
      portfolio_id.present? ? portfolio_documents(portfolio_id) : work_documents
    end

    # The portfolio plus its member works (`member_ids_ssim`), scoped by ability.
    # Returns [] if the portfolio is not found / not visible, which renders the
    # empty-map message rather than erroring.
    def portfolio_documents(portfolio_id)
      portfolio = Hyrax::SolrQueryService.new
                                         .with_field_pairs(field_pairs: { 'id' => portfolio_id })
                                         .accessible_by(ability: current_ability)
                                         .solr_documents(rows: 1).first
      return [] if portfolio.nil?

      ids = ([portfolio_id] + Array(portfolio['member_ids_ssim'])).uniq.first(MAX_WORKS)
      Hyrax::SolrQueryService.new
                             .with_field_pairs(field_pairs: { 'id' => ids }, join_with: 'OR')
                             .accessible_by(ability: current_ability)
                             .solr_documents(rows: MAX_WORKS)
    end

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

    # A node for an external URL target (a work_or_url pointing outside the
    # repository). Marked `external: true` so the view styles it as a link node
    # and opens the URL instead of a work show page.
    def url_node_for(url)
      { id: url, label: external_label(url), type: 'External link', external: true, path: url }
    end

    # A compact, human-readable label for a URL node (its host), falling back to
    # the full URL when it can't be parsed.
    def external_label(url)
      URI.parse(url).host || url
    rescue URI::InvalidURIError
      url
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
      ::Enact::RelationshipGraph.new(doc).outbound.filter_map do |edge|
        rel, rel_inverse = edge_rel_pair(edge)
        # An untyped relationship (no controlled type, no prose - possible now
        # that relationship_type is optional) has no map label or colour and no
        # legend entry, so drop it rather than emit a `null`-typed edge. The show
        # page still lists it.
        next if rel.blank?

        { source: doc['id'], target: edge.target_id, rel:, rel_inverse:,
          note: edge.note, position: edge.position, external: edge.external }
      end
    end

    # A free-text "other" edge keys by its prose, not the "other" code, so
    # distinct free-text types stay distinct on the map instead of collapsing
    # into a single "Other" node; controlled edges invert via the authority, so
    # their `rel_inverse` is left nil here (issue #107).
    def edge_rel_pair(edge)
      prose = edge.type_other.presence if edge.relation_type.blank? || edge.relation_type == 'other'
      return [edge.relation_type, nil] unless prose
      [prose, edge.type_other_inverse.presence || prose]
    end

    # Only the types present in the graph; the whole vocabulary would swamp the
    # legend.
    def rel_types(links)
      inverses = links.each_with_object({}) { |l, m| m[l[:rel]] ||= l[:rel_inverse] if l[:rel_inverse].present? }
      links.filter_map { |l| l[:rel] }.uniq.index_with { |term| rel_type(term, inverses) }
    end

    # A term absent from the authority is a free-text "other" label: shown
    # verbatim and neutral-coloured, with the curator's inverse prose.
    def rel_type(term, inverses)
      svc = ::Enact::RelationshipTypesService
      return { label: term, inverse: inverses[term].presence || term, color: svc::FALLBACK_COLOR, dc: nil } if svc.term(term).blank?

      inverse_term = svc.inverse(term)
      { label: t("enact.relationships.types.#{term}", default: svc.label(term)),
        inverse: t("enact.relationships.inverse_types.#{inverse_term}", default: svc.label(inverse_term)),
        color: svc.color(term), dc: svc.datacite(term) }
    end
  end
end
