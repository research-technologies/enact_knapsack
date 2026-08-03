# frozen_string_literal: true

# Login-gate the contributor picker's QA authorities: Hyku mounts `Qa::Engine` at
# `/authorities` with no authentication, so without these the contributor table is
# searchable and fuzzy-queryable anonymously.
#
# `prepend` is required — the knapsack engine mounts after the Qa::Engine mount,
# so a route drawn in config/routes.rb cannot shadow it.
Rails.application.routes.prepend do
  authenticate :user do
    get '/authorities/search/linked_record/contributors',
        to: 'qa/terms#search',
        defaults: { vocab: 'linked_record', subauthority: 'contributors' }
    get '/authorities/search/linked_record_similar/contributors',
        to: 'qa/terms#search',
        defaults: { vocab: 'linked_record_similar', subauthority: 'contributors' }
  end
end
