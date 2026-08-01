# frozen_string_literal: true

# Authorization for research profiles.
#
# Linking stays with admins because it asserts an identity claim about a person.
# Claiming being admin-approved is what keeps the edit grant out of reach: a user
# cannot link themselves to a profile and thereby award themselves edit rights.
module Hyrax
  module Ability
    module ContributorAbility
      def research_profile_abilities
        can :manage, :research_profile_links if admin?

        can %i[edit update], Enact::Contributor do |contributor|
          admin? || contributor.editable_by?(current_user)
        end
      end
    end
  end
end

Ability.include(Hyrax::Ability::ContributorAbility)
Ability.ability_logic |= [:research_profile_abilities]
