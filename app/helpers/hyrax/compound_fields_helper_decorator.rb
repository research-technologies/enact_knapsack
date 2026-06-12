# frozen_string_literal: true

# OVERRIDE Hyrax: render the relationships card for works that are only the
# TARGET of relationships. Upstream render_compound_cards skips a card when
# the work's own attribute is empty - but an edge is stored once, on the
# source work, so a work that other works point AT has an empty
# `relationships` of its own. Its inbound edges (found by the Solr reverse
# lookup in Enact::RelationshipGraph) would never display, and neither would
# the "Relationship map" button that lives on the card.
module Hyrax
  module CompoundFieldsHelperDecorator
    def render_compound_cards(presenter)
      rendered = super
      return rendered if presenter.try(:relationships).present? # card already rendered by super
      return rendered unless relationships_card_declared?(presenter) && inbound_relationships?(presenter)

      rendered + render('hyrax/compounds/compound_card', presenter: presenter, field: :relationships)
    rescue StandardError => e
      Hyrax.logger.debug("CompoundFieldsHelperDecorator#render_compound_cards: #{e.message}")
      rendered || ''.html_safe
    end

    private

    def relationships_card_declared?(presenter)
      compound_schema_for(presenter).card_compound_names.include?(:relationships)
    end

    # One cheap fielded count: does anything point at this work?
    def inbound_relationships?(presenter)
      Hyrax::SolrService.count("relationships_item_ssim:\"#{presenter.id}\"").positive?
    end
  end
end

Hyrax::CompoundFieldsHelper.prepend(Hyrax::CompoundFieldsHelperDecorator)
