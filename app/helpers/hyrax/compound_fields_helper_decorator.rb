# frozen_string_literal: true

# OVERRIDE Hyrax 5.2.0 Hyrax::CompoundFieldsHelper#render_compound_cards.
#
# An edge is stored once, on the source work, so a work that is only the TARGET
# of relationships has an empty `relationships` and upstream skips its card,
# hiding its inbound edges (Enact::RelationshipGraph reverse lookup) and the map
# button. Render that card here. Also render the map modal once at the cards
# level rather than inside the flex card-header, where a Bootstrap modal's fixed
# positioning and focus trap would be confined.
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
