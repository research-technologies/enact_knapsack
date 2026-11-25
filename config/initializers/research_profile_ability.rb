# frozen_string_literal: true

# Nothing references Hyrax::Ability::ContributorAbility by name
# This require is what turns the ability on.
# It touches Ability, so it must stay in to_prepare (after Hyku's locales load); an engine initializer would break RolesService translations.
Rails.application.config.to_prepare do
  require HykuKnapsack::Engine.root.join('app', 'models', 'concerns', 'hyrax', 'ability', 'contributor_ability')
end
