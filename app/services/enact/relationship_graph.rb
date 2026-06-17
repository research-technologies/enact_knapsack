# frozen_string_literal: true

module Enact
  # Reads the `relationships` compound (the "patch cables", Object Handling Spec
  # v0.2 Sec 3.5) into renderable edge lists for the read-only "related within
  # this project" block.
  #
  # An edge is stored once, on the source work's `relationships` compound, as an
  # entry keyed by the M3 members' `name:`s ({"item", "type", "position",
  # "note"}). The source's own edges are its OUTBOUND edges. A work's INBOUND
  # edges (works that point AT it) are not stored on it; they are found with a
  # Solr reverse lookup on `relationships_item_ssim` (the derived index field
  # for the `item` member). This is the single-source-of-truth design: no
  # inverse edge is duplicated onto the target.
  #
  # Edge targets are internal works (the compound's `work_or_url` field) resolved
  # to a title/path, or external URLs, emitted as external edges (the URL as both
  # title and path) so the relationships card can link to them. An internal
  # target that does not resolve to an indexed work is skipped. (The relationship
  # map still graphs work-to-work edges only; external targets are not in its
  # node set, so the map controller filters them out.)
  class RelationshipGraph
    # The DataCite-aligned controlled terms (m3 profile `relationship_type`) and
    # their inverse, used to label an inbound edge from the target's point of
    # view. Symmetric relations map to themselves.
    INVERSE_OF = {
      'sequence' => 'sequence-of',
      'source-of' => 'derived-from',
      'response-to' => 'referenced-by',
      'documents' => 'documented-by',
      'pair-with' => 'pair-with',
      'juxtaposed-with' => 'juxtaposed-with'
    }.freeze

    Edge = Struct.new(:target_id, :title, :path, :relation_type, :note, :position, :external, keyword_init: true)

    # @param document [SolrDocument, #relationships] the work whose edges we render
    def initialize(document)
      @document = document
    end

    # Edges this work itself declares, resolved to internal targets and ordered
    # so sequenced edges read in `position` order.
    # @return [Array<Edge>]
    def outbound
      edges = relationship_entries(@document).filter_map do |entry|
        build_edge(entry['item'], entry['type'], entry)
      end
      sort_edges(edges)
    end

    # Works that point AT this work, via reverse lookup on the indexed target id.
    # Each inbound edge is labeled with the inverse of the stored relation type.
    # @return [Array<Edge>]
    def inbound
      id = Array(@document.id).first
      return [] if id.blank?

      edges = sources_pointing_at(id).flat_map do |source|
        relationship_entries(source).filter_map do |entry|
          next unless entry['item'].to_s == id.to_s

          stored = entry['type']
          # Label the inbound edge with the inverse term; fall back to the
          # stored term when no inverse is mapped (e.g. legacy vocabulary).
          build_edge(source.id, INVERSE_OF.fetch(stored, stored), entry, target_id: source.id)
        end
      end
      sort_edges(edges)
    end

    private

    # The source works whose `relationships` point at the given id. Limited to a
    # generous page; a single work is not expected to be the target of more
    # inbound edges than this within one project.
    def sources_pointing_at(id)
      Hyrax::SolrService.query(
        "relationships_item_ssim:\"#{id}\"",
        fl: 'id,relationships_json_ss',
        rows: 1_000
      )
    end

    # Parse a doc/hit's `relationships` compound into an Array of entry hashes.
    # A SolrDocument exposes a coerced `relationships` reader; a SolrHit (from
    # the reverse-lookup query) only carries the raw `_json_ss` blob, so coerce
    # it directly. Entry keys come back as strings either way.
    def relationship_entries(doc)
      return Array(doc.relationships) if doc.respond_to?(:relationships)

      blob = doc['relationships_json_ss'] if doc.respond_to?(:[])
      Hyrax::SolrDocument::Metadata::Solr::CompoundEntries.coerce(blob)
    end

    # Build an Edge from a target value + relation type. Internal works are
    # resolved to their title/path; external URLs are emitted as external edges
    # (the URL is both title and path, `external: true`) so the relationships
    # card can link to them. Returns nil only for blank values or internal
    # targets that do not resolve to a real record.
    def build_edge(target_value, relation_type, entry, target_id: nil)
      target_value = target_value.to_s
      title, path, external = resolve_target(target_value)
      return nil if title.nil?

      Edge.new(target_id: target_id || target_value, title:, path:, relation_type:, external:,
               note: entry['note'].presence, position: entry['position'].presence)
    end

    # Resolve a relationship target value to [title, path, external?]. External
    # URLs use the URL as both title and path; internal ids resolve to a work's
    # title/path. Returns nil to skip a blank value or an id that does not
    # resolve to an indexed work.
    def resolve_target(target_value)
      return nil if target_value.blank?
      return [target_value, target_value, true] if Hyrax::CompoundWorkResolver.url?(target_value)

      resolved = Hyrax::CompoundWorkResolver.resolve(target_value)
      resolved.nil? ? nil : [*resolved, false]
    end

    # Sequenced edges first, in numeric position order; the rest keep their
    # natural order after them.
    def sort_edges(edges)
      positioned, unpositioned = edges.partition { |e| e.position.present? }
      positioned.sort_by { |e| e.position.to_i } + unpositioned
    end
  end
end
