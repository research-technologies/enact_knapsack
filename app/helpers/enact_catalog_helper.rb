# frozen_string_literal: true

# Blacklight index-field helpers for the catalog search results.
module EnactCatalogHelper
  # Labels item_subtype values in search results.
  #
  # Hyrax::FlexibleCatalogBehavior assigns a Blacklight helper_method only for
  # `render_as` external_link / linked / rights_statement / html, so a controlled
  # property gets none and Blacklight prints the raw Solr value.
  #
  # CONTRIBUTE BACK: the generic half — labeling a controlled property from the
  # authority its profile declares — belongs in FlexibleCatalogBehavior alongside a
  # `render_as: controlled`. Enact would still need ItemSubtypeLabels, since
  # item_subtype spans four authorities.
  #
  # @param options [Hash] Blacklight passes :value (Array) and :config
  # @return [String] the labels, comma-joined
  def item_subtype_labels(options)
    Array(options[:value]).map { |value| Enact::ItemSubtypeLabels.label_for(value) }
                          .join(', ')
  end
end
