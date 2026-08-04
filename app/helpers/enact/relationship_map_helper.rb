# frozen_string_literal: true

module Enact
  # The relationship map's entry point, shared by the default show page's
  # relationships card (hyrax/compounds/_compound_card) and the enact_show theme's
  # sidebar so every theme gates the button the same way and opens the same modal.
  module RelationshipMapHelper
    # Explicit rather than relying on both modules landing in the same view context:
    # the trigger below is built from enact_map_trigger.
    include ::Enact::MapModalHelper

    # Resolved edges in both directions, memoized per work: the card body renders
    # them and the button gate counts them, and resolving one target costs a Solr
    # lookup.
    def enact_relationship_edges(presenter)
      @enact_relationship_edges ||= {}
      @enact_relationship_edges[presenter.id] ||= begin
        graph = ::Enact::RelationshipGraph.new(presenter.solr_document)
        { outbound: graph.outbound, inbound: graph.inbound }
      end
    end

    # The map button, or nothing at all when the map would open empty (issue #161).
    def enact_relationship_map_trigger(presenter, html_class: 'btn btn-outline-secondary btn-sm enact-relationship-map-link')
      return '' unless enact_relationship_map?(presenter)

      enact_map_trigger(t('enact.relationships.map_button'), enact_relationship_map_path(presenter),
                        html_class:)
    end

    # Whether the map has anything to draw for this work. An edge reaches the map
    # only when it is typed (Edge#typed?) and its other end is something the map can
    # plot: an external URL, or a work this user is allowed to see. A listed
    # relationship is not on its own proof of a non-empty map, because the card
    # resolves targets without an ability check (Hyrax::CompoundWorkResolver) while
    # every query behind the map is ability-scoped.
    def enact_relationship_map?(presenter)
      edges = enact_relationship_edges(presenter).values.flatten.select(&:typed?)
      return false if edges.empty?
      return true if edges.any?(&:external)

      enact_visible_work?(edges.map(&:target_id).compact.uniq)
    rescue StandardError => e
      Hyrax.logger.debug("enact_relationship_map?(#{presenter.try(:id)}): #{e.message}")
      false
    end

    # A Portfolio opens the whole-project diagram, any other work its focused view.
    def enact_relationship_map_path(presenter)
      key = Array(presenter.solr_document['has_model_ssim']).first.to_s == 'Portfolio' ? :portfolio : :focus

      HykuKnapsack::Engine.routes.url_helpers.relationship_map_path(key => presenter.id)
    end

    private

    def enact_visible_work?(ids)
      return false if ids.blank?

      Hyrax::SolrQueryService.new
                             .with_field_pairs(field_pairs: { 'id' => ids }, join_with: 'OR')
                             .accessible_by(ability: current_ability)
                             .count.positive?
    end
  end
end
