# frozen_string_literal: true

# Label item_subtype in catalog search results (see
# Enact::CatalogSubtypeLabels for why Hyrax leaves it raw).
#
# Prepended in to_prepare: CatalogController is app-autoloaded, so it is not
# resolvable at plain initializer time, and this re-applies on each dev reload.
Rails.application.config.to_prepare do
  CatalogController.prepend(Enact::CatalogSubtypeLabels)
end
