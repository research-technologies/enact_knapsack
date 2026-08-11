# frozen_string_literal: true

module Enact
  # Labels item_subtype in catalog search results.
  #
  # Hyrax::FlexibleCatalogBehavior registers an index field for every profile
  # property but assigns a Blacklight helper_method only for `render_as`
  # external_link / linked / rights_statement / html. A controlled property gets
  # none, so Blacklight prints the stored URI.
  #
  # Hooked after load_flexible_schema (which runs in the controller's #initialize)
  # because the field does not exist until then.
  #
  # CONTRIBUTE BACK: the generic half — labeling a controlled property from the
  # authority its own profile declares — belongs in FlexibleCatalogBehavior next to a
  # `render_as: controlled`. Enact would still need ItemSubtypeLabels, since
  # item_subtype spans four authorities and `controlled_values.sources` is read
  # first-entry-only.
  module CatalogSubtypeLabels
    def initialize
      super
      Enact::CatalogSubtypeLabels.apply!(self.class.blacklight_config)
    end

    # Idempotent: load_flexible_schema re-runs per controller instance.
    def self.apply!(config)
      field = config.index_fields['item_subtype_tesim']
      return if field.nil? || field.helper_method == :item_subtype_labels

      field.helper_method = :item_subtype_labels
      # index_field_link and friends read the field name off the config.
      field.field_name = 'item_subtype'
    end
  end
end
