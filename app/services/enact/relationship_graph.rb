# frozen_string_literal: true

module Enact
  # Reads the `relationships` compound (the "patch cables", Object Handling Spec
  # v0.2 Sec 3.5) into renderable edge lists for the read-only "related within
  # this project" block.
  #
  # An edge is stored once, on the source work's `relationships` compound, as an
  # entry keyed by the M3 members' `name:`s ({"item", "type", "type_other",
  # "type_other_inverse", "position", "note"}). A controlled `type` may be left
  # blank (or set to the "other" term) and described in the free-text
  # `type_other`, mirroring the contributors `role`/`role_other` pair; issue #107.
  # The source's own edges are its OUTBOUND edges. A work's INBOUND
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
    # On an inbound edge `type_other` holds the *inverse* prose, not the forward
    # label, so the view can render both directions with identical logic.
    Edge = Struct.new(:target_id, :title, :path, :relation_type, :type_other, :type_other_inverse,
                      :note, :position, :external, keyword_init: true)

    # @param document [SolrDocument, #relationships] the work whose edges we render
    def initialize(document)
      @document = document
    end

    # Edges this work itself declares, resolved to internal targets and ordered
    # so sequenced edges read in `position` order.
    # @return [Array<Edge>]
    def outbound
      edges = relationship_entries(@document).filter_map do |entry|
        build_edge(entry['item'], entry, labels: forward_labels(entry))
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

          build_edge(source.id, entry, labels: inverse_labels(entry), target_id: source.id)
        end
      end
      sort_edges(edges)
    end

    private

    # `other_inverse` is carried only so the map can label a free-text edge's
    # target's-side reading; the outbound show page ignores it.
    def forward_labels(entry)
      { code: entry['type'].presence, other: entry['type_other'].presence,
        other_inverse: entry['type_other_inverse'].presence }
    end

    # A free-text type has no authority inverse, so it inverts through the
    # curator's `type_other_inverse`, falling back to the forward prose (i.e. a
    # symmetric relationship).
    def inverse_labels(entry)
      code = entry['type'].present? ? Enact::RelationshipTypesService.inverse(entry['type']) : nil
      other = entry['type_other'].present? ? (entry['type_other_inverse'].presence || entry['type_other']) : nil
      { code:, other:, other_inverse: nil }
    end

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

    # External URLs are emitted as external edges (`external: true`, URL as both
    # title and path) so the card can link out; a blank value or an internal id
    # that no longer resolves to a record returns nil and is skipped.
    def build_edge(target_value, entry, labels:, target_id: nil)
      target_value = target_value.to_s
      title, path, external = resolve_target(target_value)
      return nil if title.nil?

      Edge.new(target_id: target_id || target_value, title:, path:,
               relation_type: labels[:code], type_other: labels[:other],
               type_other_inverse: labels[:other_inverse], external:,
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
