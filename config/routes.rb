# frozen_string_literal: true
HykuKnapsack::Engine.routes.draw do
  # Enact relationship map (patch cables, Object Handling Spec v0.2 Sec 3.5).
  # `?focus=<work id>` centres the graph on one work; the entry button lives in
  # the relationship card on the work show page.
  # Leading slash on the controller escapes the isolated engine's namespace so
  # this resolves to the top-level Enact::RelationshipMapController (matching
  # #32's Enact:: conventions), not HykuKnapsack::Enact::.
  get '/relationship-map', to: '/enact/relationship_map#show', as: :relationship_map
end
