# frozen_string_literal: true

# OVERRIDE Hyku v7.1.0 / Hyrax v5.2.0 (samvera/hyrax main @ 568ec626)
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
Ability.ability_logic |= [:disable_collection_creation]
