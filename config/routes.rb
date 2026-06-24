# frozen_string_literal: true
HykuKnapsack::Engine.routes.draw do
  # Enact relationship map (patch cables, Object Handling Spec v0.2 Sec 3.5).
  # `?focus=<work id>` centres the graph on one work; the entry button lives in
  # the relationship card on the work show page.
  # Leading slash on the controller escapes the isolated engine's namespace so
  # this resolves to the top-level Enact::RelationshipMapController (matching
  # #32's Enact:: conventions), not HykuKnapsack::Enact::.
  get '/relationship-map', to: '/enact/relationship_map#show', as: :relationship_map

  # Enact contributor profiles (person/organization). Index lists all
  # contributors (linked from the home page's Featured Researcher tab); show is
  # an individual profile. Leading slash escapes the isolated engine namespace
  # -> top-level Enact::ContributorsController.
  get '/contributors', to: '/enact/contributors#index', as: :enact_contributors
  # Edit/update are admin-gated in the controller (Phase 1: no owner/claim yet).
  get '/contributors/:id/edit', to: '/enact/contributors#edit', as: :edit_enact_contributor
  patch '/contributors/:id', to: '/enact/contributors#update'
  put '/contributors/:id', to: '/enact/contributors#update'
  get '/contributors/:id', to: '/enact/contributors#show', as: :enact_contributor

  # NOTE: the linked_record inline-create endpoint (POST /linked_records/:source)
  # is provided by Hyrax (Hyrax::CompoundLinkedRecordsController) now that the
  # generic linked_record feature lives in the gem; no knapsack route needed.
end
