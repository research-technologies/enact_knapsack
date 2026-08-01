# frozen_string_literal: true

# Nothing references Hyrax::Ability::ContributorAbility by name
# This require is what turns the ability on.
Rails.application.config.to_prepare do
  require HykuKnapsack::Engine.root.join('app', 'models', 'concerns', 'hyrax', 'ability', 'contributor_ability')
end
