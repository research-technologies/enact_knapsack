# frozen_string_literal: true

# Use this to override any Hyrax configuration from the Knapsack

Rails.application.config.after_initialize do
  Hyrax.config do |config|
    config.flexible = ActiveModel::Type::Boolean.new.cast(ENV.fetch('HYRAX_FLEXIBLE', 'false'))

    # Prepend to ensure knapsack profile is checked before the host app's profiles.
    config.schema_loader_config_search_paths.unshift(HykuKnapsack::Engine.root) \
      if config.respond_to?(:schema_loader_config_search_paths)

    # Enact work types - parent narrative container + typed child item.
    config.register_curation_concern :portfolio
    config.register_curation_concern :portfolio_item

    # Prototype: typed-work-types alternative. Four sibling work types in
    # place of one PortfolioItem with a portfolio_item_type discriminator.
    # Tenants can enable/disable each via Admin > Work types.
    config.register_curation_concern :portfolio_artefact
    config.register_curation_concern :portfolio_event
    config.register_curation_concern :portfolio_literature
    config.register_curation_concern :portfolio_collection
  end
end
