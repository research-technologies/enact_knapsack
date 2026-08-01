# frozen_string_literal: true

require 'rails_helper'

# The contributor picker's autocomplete and "did you mean" duplicate check, served
# by Hyrax's generic QA authorities. Qa::Engine is mounted without authentication,
# so the login gate lives in config/initializers/enact_authorities_auth.rb — these
# specs pin it.
#
# :singletenant — routing is multitenancy-sensitive in Hyku; without it the bare
# path requests 404 because the request carries no tenant host.
RSpec.describe 'Enact contributor QA authorities', type: :request, singletenant: true do
  let!(:ada) do
    Enact::Contributor.create!(display_name: 'Ada Lovelace',
                               orcid: 'https://orcid.org/0000-0002-1825-0097')
  end

  def rows
    JSON.parse(response.body)
  end

  describe 'GET /authorities/search/linked_record/contributors (typeahead)' do
    context 'as a signed-in depositor' do
      before { login_as(FactoryBot.create(:user), scope: :user) }

      it 'returns matching contributors' do
        get '/authorities/search/linked_record/contributors', params: { q: 'lovelace' }
        expect(response).to have_http_status(:ok)
        expect(rows.map { |r| r['id'] }).to include(ada.id.to_s)
      end

      # QA itself rejects a blank/whitespace `q` with a 400 before the source is
      # reached; the source's own blank guard (see the picker-procs spec) is the
      # backstop for any other caller.
      it 'rejects a whitespace-only term rather than enumerating the table' do
        get '/authorities/search/linked_record/contributors', params: { q: '   ' }
        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'anonymously' do
      it 'redirects to sign-in instead of exposing contributors' do
        get '/authorities/search/linked_record/contributors', params: { q: 'lovelace' }
        expect(response).to have_http_status(:redirect)
        expect(response.body).not_to include('Ada Lovelace')
      end
    end
  end

  describe 'GET /authorities/search/linked_record_similar/contributors (duplicate check)' do
    context 'as a signed-in depositor' do
      before { login_as(FactoryBot.create(:user), scope: :user) }

      it 'surfaces a fuzzy match so the curator can reuse it' do
        get '/authorities/search/linked_record_similar/contributors', params: { q: 'Ada Lovelice' }
        expect(response).to have_http_status(:ok)
        expect(rows.map { |r| r['id'] }).to include(ada.id.to_s)
      end
    end

    context 'anonymously' do
      it 'is not fuzzy-queryable' do
        get '/authorities/search/linked_record_similar/contributors', params: { q: 'Ada Lovelice' }
        expect(response).to have_http_status(:redirect)
        expect(response.body).not_to include('Ada Lovelace')
      end
    end
  end
end
