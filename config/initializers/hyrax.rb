# frozen_string_literal: true

# Use this to override any Hyrax configuration from the Knapsack

Rails.application.config.after_initialize do
  Hyrax.config do |config|
    # Default to ON on the spike-flexible-metadata branch; the Enact M3 profile
    # at config/metadata_profiles/m3_profile.yaml drives subtype-aware deposit
    # forms. Set HYRAX_FLEXIBLE=false in the environment to temporarily fall
    # back to the static SimpleSchemaLoader path in config/metadata/*.yaml.
    config.flexible = ActiveModel::Type::Boolean.new.cast(ENV.fetch('HYRAX_FLEXIBLE', 'true'))

    # Prepend to ensure knapsack profile is checked before the host app's profiles.
    config.schema_loader_config_search_paths.unshift(HykuKnapsack::Engine.root) \
      if config.respond_to?(:schema_loader_config_search_paths)

    # On the spike-flexible-metadata branch, Enact work types must opt into the
    # M3 profile so their attributes (depositor, title, description, the PR
    # Voices fields, the compounds) get loaded from the FlexibleSchema instead
    # of being undefined at runtime. Without this, `Hyrax::Resource.inherited`
    # skips `acts_as_flexible_resource` for these classes and instances raise
    # `NoMethodError: undefined method 'depositor='` on form-build.
    # The default flexible_classes set is just [collection, file_set, admin_set];
    # the work types below are the Enact additions.
    config.flexible_classes = [
      config.collection_model,
      config.file_set_model,
      config.admin_set_model,
      'Portfolio',
      'PortfolioItem',
      'PortfolioArtefact',
      'PortfolioEvent',
      'PortfolioLiterature',
      'PortfolioItemCollection'
    ].uniq

    # Enact work types - parent narrative container + typed child item.
    config.register_curation_concern :portfolio
    config.register_curation_concern :portfolio_item

    # Prototype: typed-work-types alternative. Four sibling work types in
    # place of one PortfolioItem with a portfolio_item_type discriminator.
    # Tenants can enable/disable each via Admin > Work types.
    config.register_curation_concern :portfolio_artefact
    config.register_curation_concern :portfolio_event
    config.register_curation_concern :portfolio_literature
    config.register_curation_concern :portfolio_item_collection
  end
end
