# frozen_string_literal: true

# Hyrax configuration for Enact work types.

Rails.application.config.after_initialize do
  Hyrax.config do |config|
    # Flexible metadata on by default; the M3 profile at
    # config/metadata_profiles/m3_profile.yaml drives every Enact work type.
    config.flexible = ActiveModel::Type::Boolean.new.cast(ENV.fetch('HYRAX_FLEXIBLE', 'true'))

    # Prepend the knapsack profile so it loads ahead of the host app's profiles.
    config.schema_loader_config_search_paths.unshift(HykuKnapsack::Engine.root) \
      if config.respond_to?(:schema_loader_config_search_paths)

    # Enact work types must opt into the M3 profile so attributes (depositor,
    # title, description, the PR Voices fields, the compounds) get loaded from
    # the FlexibleSchema. Without this, `Hyrax::Resource.inherited` skips
    # `acts_as_flexible_resource` for them and instances raise
    # `NoMethodError: undefined method 'depositor='` on form-build.
    config.flexible_classes = [
      config.collection_model,
      config.file_set_model,
      config.admin_set_model,
      'Portfolio',
      'PortfolioArtefact',
      'PortfolioEvent',
      'PortfolioLiterature',
      'PortfolioItemCollection'
    ].uniq

    # Portfolio: narrative parent container.
    config.register_curation_concern :portfolio

    # Four typed child work types. Tenants can enable / disable each via
    # Admin > Work types.
    config.register_curation_concern :portfolio_artefact
    config.register_curation_concern :portfolio_event
    config.register_curation_concern :portfolio_literature
    config.register_curation_concern :portfolio_item_collection
  end
end
