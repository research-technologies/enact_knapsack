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

    # Opt-in gate: the map only works when the tenant's metadata profile declares
    # the `relationships` compound (see docs/relationship-map-setup.md). Without
    # it there is nothing to draw, so the standalone page 404s rather than showing
    # an empty graph. The in-page "Relationship map" button is already implicitly
    # gated - it renders only inside the relationships compound card, which the
    # profile drives.
    before_action :require_relationships_compound, only: :show

    def show
      scope = ::Enact::RelationshipMapScope.new(ability: current_ability, portfolio_id: params[:portfolio])
      docs = scope.documents
      links = kept_links(docs)
      @graph = { nodes: graph_nodes(docs, links), links: }
      @rel_types = rel_types(links)
      @focus = params[:focus].to_s
      @truncated = scope.truncated?
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
        # An untyped relationship has no map label, colour, or legend entry, so drop
        # it rather than emit a `null`-typed edge; see Edge#typed?.
        next unless edge.typed?

        rel, rel_inverse = edge.rel_pair
        { source: doc['id'], target: edge.target_id, rel:, rel_inverse:,
          note: edge.note, position: edge.position, external: edge.external }
      end
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
