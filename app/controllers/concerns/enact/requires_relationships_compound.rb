# frozen_string_literal: true

module Enact
  # Opt-in gate for the relationship map: only serve it when the tenant's
  # metadata profile declares the `relationships` compound (see
  # docs/relationship-map-setup.md). Kept generic (any registered work type /
  # the active profile exposing the attribute) so the feature is portable
  # beyond Enact.
  module RequiresRelationshipsCompound
    extend ActiveSupport::Concern

    private

    def require_relationships_compound
      return if relationships_compound_configured?

      render plain: 'Relationship map is not enabled for this repository.', status: :not_found
    end

    # The map is enabled when the tenant's metadata declares the `relationships`
    # compound. In flexible mode (HYRAX_FLEXIBLE=true) the compound lives in the
    # active M3 profile's `properties`, NOT in the class-level `attribute_names`
    # (those only carry the base Valkyrie attributes), so check the flexible
    # profile first; fall back to the class attributes for classic metadata mode.
    def relationships_compound_configured?
      flexible_profile_declares_relationships? || work_type_declares_relationships?
    rescue StandardError
      false
    end

    # Flexible mode: read the current M3 profile and look for the `relationships`
    # property. Returns false in classic mode (handled by the class-attribute path).
    def flexible_profile_declares_relationships?
      return false unless ::Hyrax.config.respond_to?(:flexible?) && ::Hyrax.config.flexible?

      profile = ::Hyrax::FlexibleSchema.order(:created_at).last&.profile
      properties = profile.is_a?(Hash) ? (profile['properties'] || profile['attributes']) : nil
      properties.is_a?(Hash) && properties.key?('relationships')
    end

    # Classic mode: any registered work type declaring a `relationships`
    # attribute at the class level. No query, holds without flexible metadata.
    def work_type_declares_relationships?
      ::Hyrax.config.registered_curation_concern_types.any? do |type|
        klass = type.safe_constantize
        klass.respond_to?(:attribute_names) && klass.attribute_names.map(&:to_sym).include?(:relationships)
      end
    end
  end
end
