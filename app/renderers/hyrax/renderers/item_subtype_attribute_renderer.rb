# frozen_string_literal: true

module Hyrax
  module Renderers
    # Renders item_subtype as its authority label (see Enact::ItemSubtypeLabels)
    # rather than the stored URI. Hyrax has no renderer that labels a value from its
    # property's authority: `faceted` links the raw value and the license/rights
    # renderers are hardcoded to their own services.
    class ItemSubtypeAttributeRenderer < AttributeRenderer
      private

      # Plain text: the value is an external vocabulary URI (schema.org, Getty,
      # DataCite), and the base renderer's auto_link would link readers off-site.
      def li_value(value)
        ERB::Util.h(Enact::ItemSubtypeLabels.label_for(value))
      end
    end
  end
end
