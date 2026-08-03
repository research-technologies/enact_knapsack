# frozen_string_literal: true
HykuKnapsack::Engine.routes.draw do
  # Enact relationship map (patch cables, Object Handling Spec v0.2 Sec 3.5).
  # `?focus=<work id>` centres the graph on one work; the entry button lives in
  # the relationship card on the work show page.
  # Leading slash on the controller escapes the isolated engine's namespace so
  # this resolves to the top-level Enact::RelationshipMapController (matching
  # #32's Enact:: conventions), not HykuKnapsack::Enact::.
  get '/relationship-map', to: '/enact/relationship_map#show', as: :relationship_map

  # Enact "research network" people map: contributors as nodes, linked where they
  # share credit on a work, coloured by institution. Companion to the work
  # relationship map above; the leading slash escapes the isolated engine
  # namespace -> top-level Enact::PeopleMapController.
  get '/people-map', to: '/enact/people_map#show', as: :people_map

  # Enact contributor profiles (person/organization). Index lists all
  # contributors (linked from the home page's Featured Researcher tab); show is
  # an individual profile. Leading slash escapes the isolated engine namespace
  # -> top-level Enact::ContributorsController.
  get '/contributors', to: '/enact/contributors#index', as: :enact_contributors
  # The picker's fuzzy "did you mean" duplicate check is served by Hyrax's generic
  # linked_record_similar QA authority (ContributorSource registers a `similar:`
  # proc), so no knapsack route is needed.
  get '/contributors/:id/edit', to: '/enact/contributors#edit', as: :edit_enact_contributor
  patch '/contributors/:id', to: '/enact/contributors#update'
  put '/contributors/:id', to: '/enact/contributors#update'
  # These two must stay above the /contributors/:id catch-all below.
  post '/contributors/:contributor_id/claim', to: '/enact/profile_requests#create',
                                              as: :claim_enact_contributor
  delete '/contributors/:contributor_id/link', to: '/enact/user_profile_links#unlink',
                                               as: :enact_contributor_link
  get '/contributors/:id', to: '/enact/contributors#show', as: :enact_contributor

  # Singular here, plural for the admin worklist below — distinct names on
  # purpose, so a mis-link fails loudly rather than landing on the wrong page.
  get '/dashboard/research-profile', to: '/enact/profile_requests#show',
                                     as: :dashboard_research_profile
  post '/dashboard/research-profile/requests', to: '/enact/profile_requests#create',
                                               as: :dashboard_research_profile_requests
  delete '/dashboard/research-profile/requests/:id', to: '/enact/profile_requests#destroy',
                                                     as: :dashboard_research_profile_request

  get '/dashboard/research-profiles', to: '/enact/user_profile_links#index',
                                      as: :dashboard_research_profiles
  get '/dashboard/research-profiles/:user_id/link', to: '/enact/user_profile_links#new',
                                                    as: :new_dashboard_research_profile_link
  get '/dashboard/research-profiles/:user_id/profile/new', to: '/enact/user_profile_links#new_profile',
                                                           as: :new_dashboard_research_profile
  post '/dashboard/research-profiles/:user_id/link', to: '/enact/user_profile_links#create',
                                                     as: :dashboard_research_profile_link
  delete '/dashboard/research-profiles/:user_id/link', to: '/enact/user_profile_links#unlink'
  post '/dashboard/research-profiles/requests/:id/decline', to: '/enact/user_profile_links#decline',
                                                            as: :decline_dashboard_research_profile_request

  get '/check-iiif', to: '/enact/iiif#show', as: :iiif
  # NOTE: the linked_record inline-create endpoint (POST /linked_records/:source)
  # is provided by Hyrax (Hyrax::CompoundLinkedRecordsController) now that the
  # generic linked_record feature lives in the gem; no knapsack route needed.

  # HLS streaming. format: false keeps the .m3u8/.ts extension in *path; leading
  # slash escapes the engine namespace to the top-level Hyrax::HlsController.
  get '/file_sets/:id/hls/*path', to: '/hyrax/hls#show', as: :file_set_hls, format: false

  get '/dashboard/job_statuses', to: '/hyrax/dashboard/job_statuses#index', as: :dashboard_job_statuses
end
