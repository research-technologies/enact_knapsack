# frozen_string_literal: true

# Hyrax configuration for Enact work types.

# Set load-time-sensitive config at initializer-evaluation time (NOT inside
# `Rails.application.config.after_initialize`). In production eager-load runs
# before `after_initialize`, so anything that affects how the work-type
# classes evaluate at class-load - `flexible`, `disable_include_metadata`,
# `flexible_classes`, the M3 search path - has to be in place before then.
# Symptoms when this is wrong: `Hyrax::SchemaLoader::UndefinedSchemaError:
# No schema defined: portfolio_artefact` (because `work_include_metadata?`
# was still true at class-load and `include Hyrax::Schema(:portfolio_artefact)`
# fired before we shipped a static YAML for it), or `NoMethodError: undefined
# method 'depositor='` (because `Hyrax::Resource.inherited` skipped
# `acts_as_flexible_resource` for a class not yet in `flexible_classes`).
Hyrax.config do |config|
  config.flexible = ActiveModel::Type::Boolean.new.cast(ENV.fetch('HYRAX_FLEXIBLE', 'true'))

  # Flex-only branch: no static `config/metadata/*.yaml` files are shipped, so
  # the per-work-type `include Hyrax::Schema(:portfolio_artefact)` blocks
  # must be skipped. `work_include_metadata?` defaults to true; this disables
  # it (and the parallel file_set / collection / admin_set variants).
  config.disable_include_metadata = true

  # Prepend the knapsack profile so it loads ahead of the host app's profiles.
  config.schema_loader_config_search_paths.unshift(HykuKnapsack::Engine.root) \
    if config.respond_to?(:schema_loader_config_search_paths)

  # Opt every Enact work type into the M3 profile. Default `flexible_classes`
  # is just [collection, file_set, admin_set]; without these additions,
  # `Hyrax::Resource.inherited` skips `acts_as_flexible_resource` for the
  # work types and `depositor=` etc. are undefined on instances.
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
end

# Curation-concern registration needs the work-type constants resolvable, so
# defer it to after_initialize when Zeitwerk has set up autoload paths.
Rails.application.config.after_initialize do
  Hyrax.config do |config|
    # Portfolio: narrative parent container.
    config.register_curation_concern :portfolio

    # Four typed child work types. Tenants can enable / disable each via
    # Admin > Work types.
    config.register_curation_concern :portfolio_artefact
    config.register_curation_concern :portfolio_event
    config.register_curation_concern :portfolio_literature
    config.register_curation_concern :portfolio_item_collection

    # Strip Hyku's default work types (GenericWork, Image, Etd, Oer) so only
    # the Enact types are deposit-able. Hyrax::Configuration stores the
    # concern list in @registered_concerns and exposes only an additive
    # `register_curation_concern` API, so we reset the ivar directly.
    # Both Hyku's `QuickClassificationQuery` picker and the Admin > Work
    # types page read from this list, so resetting here covers both. New
    # tenants pick up the trimmed list automatically at create time (Site
    # seeds `available_works` from it - see hyrax-webapp/app/models/site.rb).
    # Existing tenants need their `Site.instance.available_works` updated
    # once, e.g.:
    #   Account.find_each { |a| Apartment::Tenant.switch(a.tenant) {
    #     Site.instance.update!(available_works: Hyrax.config.registered_curation_concern_types)
    #   } }
    config.instance_variable_set(
      :@registered_concerns,
      %i[portfolio portfolio_artefact portfolio_event portfolio_literature portfolio_item_collection]
    )
  end
end
