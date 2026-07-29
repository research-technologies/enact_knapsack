# frozen_string_literal: true

# OVERRIDE Hyrax 5.2.0 Hyrax::CompoundFieldsHelper#render_compound_cards for two
# enact concerns:
#
# 1. Render the relationships card for works that are only the TARGET of
#    relationships. Upstream skips a card when the work's own attribute is empty
#    - but an edge is stored once, on the source work, so a work that other works
#    point AT has an empty `relationships` of its own. Its inbound edges (found by
#    the Solr reverse lookup in Enact::RelationshipGraph) would never display, and
#    neither would the "Relationship map" button that lives on the card.
#
# 2. Render the map iframe modal once here, at the cards level. The map trigger
#    lives on the relationships card, so the modal is needed exactly when that
#    card shows. Doing it here (not inside the flex card-header) keeps the modal
#    at a top-level position so its fixed positioning/focus trap are not confined.
module Hyrax
  module CompoundFieldsHelperDecorator
    def render_compound_cards(presenter)
      rendered = super
      inbound_only = inbound_only_relationships_card?(presenter)
      rendered += render('hyrax/compounds/compound_card', presenter:, field: :relationships) if inbound_only
      rendered += render('enact/shared/map_modal') if presenter.try(:relationships).present? || inbound_only
      rendered
    rescue StandardError => e
      Hyrax.logger.debug("CompoundFieldsHelperDecorator#render_compound_cards: #{e.message}")
      rendered || ''.html_safe
    end

    private

    # A relationships card is present but only via inbound edges (the work's own
    # `relationships` is empty), so super did not render it.
    def inbound_only_relationships_card?(presenter)
      presenter.try(:relationships).blank? &&
        relationships_card_declared?(presenter) &&
        inbound_relationships?(presenter)
    end

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
