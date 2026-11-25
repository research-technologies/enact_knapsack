# frozen_string_literal: true

# OVERRIDE Hyku v7.1.0 / Hyrax v5.2.0
#
# Disable User Collection creation for everyone (#94). Create is granted from
# three places (admin?, the Hyku collection roles, and the collection type's
# create participants), so we revoke it in the ability. Only :create/:create_any
# are removed - :manage survives, and Admin Sets (a separate model) are untouched.
module Hyrax
  module Ability
    module CollectionAbilityDecorator
      def disable_collection_creation
        cannot %i[create create_any], collection_models
      end
    end
  end
end

Hyrax::Ability::CollectionAbility.prepend(Hyrax::Ability::CollectionAbilityDecorator)

# Append last so `cannot` overrides earlier grants; `|=` avoids duplicates on reload.
# Deferred: this file loads in the engine's to_prepare, before Hyku adds its locales, and referencing
# Ability here loads RolesService, which freezes I18n.t into a constant ("Translation missing" group names).
Rails.application.config.after_initialize do
  Ability.ability_logic |= [:disable_collection_creation]
end
