# frozen_string_literal: true

module Enact
  # Opt-in gate for the relationship map: only serve it when the tenant's
  # metadata profile declares the `relationships` compound (see
  # docs/relationship-map-setup.md). Kept generic (any registered work type
  # exposing the attribute) so the feature is portable beyond Enact.
  module RequiresRelationshipsCompound
    extend ActiveSupport::Concern

    private

    def require_relationships_compound
      return if relationships_compound_configured?

      render plain: 'Relationship map is not enabled for this repository.', status: :not_found
    end

    # Class-level attribute introspection, so it holds in both flexible and
    # classic metadata modes and needs no query.
    def relationships_compound_configured?
      ::Hyrax.config.registered_curation_concern_types.any? do |type|
        klass = type.safe_constantize
        klass.respond_to?(:attribute_names) && klass.attribute_names.map(&:to_sym).include?(:relationships)
      end
    rescue StandardError
      false
    end
  end
end
