# frozen_string_literal: true

# Blacklight index-field helpers for the catalog search results.
module EnactCatalogHelper
  # Labels item_subtype values in search results. Registered on the index field by
  # Enact::CatalogSubtypeLabels, which explains why Hyku leaves it unset and what
  # belongs upstream.
  #
  # @param options [Hash] Blacklight passes :value (Array) and :config
  # @return [String] the labels, comma-joined
  def item_subtype_labels(options)
    Array(options[:value]).map { |value| Enact::ItemSubtypeLabels.label_for(value) }
                          .join(', ')
  end
end
