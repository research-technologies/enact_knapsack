# frozen_string_literal: true

module Enact
  # The relationship map's entry point, shared by the default show page's relationships
  # card (hyrax/compounds/_compound_card) and the enact_show theme's sidebar so the
  # themes cannot drift apart again (issues #161, #177).
  module RelationshipMapHelper
    # Explicit, so this module carries its own dependency rather than relying on both
    # landing in the same view context.
    include ::Enact::MapModalHelper

    # Memoized per work: the card body and the button gate both need these, and each
    # resolved target costs a Solr lookup. Ability-scoped so the card never lists a
    # work this viewer cannot open (issue #182).
    def enact_relationship_edges(presenter)
      @enact_relationship_edges ||= {}
      @enact_relationship_edges[presenter.id] ||= begin
        graph = ::Enact::RelationshipGraph.new(presenter.solr_document, ability: current_ability)
        { outbound: graph.outbound, inbound: graph.inbound }
      end
    end

    def enact_relationship_map_trigger(presenter, html_class: 'btn btn-outline-secondary btn-sm enact-relationship-map-link')
      return '' unless enact_relationship_map?(presenter)

      enact_map_trigger(t('enact.relationships.map_button'), enact_relationship_map_path(presenter),
                        html_class:)
    end

    # The edges are already ability-scoped (issue #182), so anything that resolved is
    # drawable; only an untyped edge, which the map cannot label, keeps the button away.
    def enact_relationship_map?(presenter)
      enact_relationship_edges(presenter).values.flatten.any?(&:typed?)
    rescue StandardError => e
      Hyrax.logger.debug("enact_relationship_map?(#{presenter.try(:id)}): #{e.message}")
      false
    end

    # A Portfolio opens the whole-project diagram, any other work its focused view.
    def enact_relationship_map_path(presenter)
      key = Array(presenter.solr_document['has_model_ssim']).first.to_s == 'Portfolio' ? :portfolio : :focus

      HykuKnapsack::Engine.routes.url_helpers.relationship_map_path(key => presenter.id)
    end
  end
end
