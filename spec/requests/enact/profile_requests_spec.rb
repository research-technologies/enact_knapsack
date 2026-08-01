# frozen_string_literal: true

require 'rails_helper'

# The user-facing side of research-profile claiming: asking for a profile, or
# claiming a specific unclaimed one.
RSpec.describe 'Enact research profile requests', type: :request, singletenant: true do
  let(:user) { FactoryBot.create(:user) }
  let!(:ada) { Enact::Contributor.create!(display_name: 'Ada Lovelace') }

  describe 'GET /dashboard/research-profile' do
    it 'redirects an anonymous visitor to sign in' do
      get '/dashboard/research-profile'
      expect(response).to have_http_status(:found)
    end

    context 'when signed in without a profile' do
      before { login_as(user, scope: :user) }

      it 'offers to request one' do
        get '/dashboard/research-profile'
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Request a research profile')
      end
    end

    context 'when an earlier request was declined' do
      before do
        Enact::ProfileRequest.create!(user:)
                             .decline!(by: FactoryBot.create(:admin), note: 'Could not verify identity.')
        login_as(user, scope: :user)
      end

      it 'says the request was declined, with the reason' do
        get '/dashboard/research-profile'
        expect(response.body).to include('declined')
        expect(response.body).to include('Could not verify identity.')
      end

      it 'still offers to request again' do
        get '/dashboard/research-profile'
        expect(response.body).to include('Request a research profile')
      end

      # The decision is the user's to see; who made it is internal.
      it 'does not name the reviewer' do
        reviewer = Enact::ProfileRequest.last.reviewed_by
        get '/dashboard/research-profile'
        expect(response.body).not_to include(reviewer.email)
      end

      it 'shows only the most recent decline' do
        Enact::ProfileRequest.create!(user:)
                             .decline!(by: FactoryBot.create(:admin), note: 'A second, newer reason.')
        get '/dashboard/research-profile'
        expect(response.body).to include('A second, newer reason.')
        expect(response.body).not_to include('Could not verify identity.')
      end
    end

    it 'says nothing about declines when there are none' do
      login_as(user, scope: :user)
      get '/dashboard/research-profile'
      expect(response.body).not_to include('declined')
    end

    context 'when a request is already pending' do
      before do
        Enact::ProfileRequest.create!(user:)
        login_as(user, scope: :user)
      end

      it 'shows the pending state instead of the request form' do
        get '/dashboard/research-profile'
        expect(response.body).to include('awaiting review')
        expect(response.body).not_to include('Request a research profile')
      end
    end

    context 'when a profile is linked' do
      before do
        ada.update!(user:)
        login_as(user, scope: :user)
      end

      it 'redirects to the profile itself' do
        get '/dashboard/research-profile'
        expect(response).to redirect_to("/contributors/#{ada.id}")
      end
    end
  end

  describe 'POST /dashboard/research-profile/requests' do
    before { login_as(user, scope: :user) }

    it 'creates a pending request with no target' do
      expect { post '/dashboard/research-profile/requests' }
        .to change(Enact::ProfileRequest, :count).by(1)
      expect(Enact::ProfileRequest.last).to be_pending
      expect(Enact::ProfileRequest.last.contributor).to be_nil
    end

    it 'stores an optional note' do
      post '/dashboard/research-profile/requests', params: { profile_request: { note: 'I deposit under Ada L.' } }
      expect(Enact::ProfileRequest.last.note).to eq('I deposit under Ada L.')
    end

    it 'does not stack a second pending request' do
      post '/dashboard/research-profile/requests'
      expect { post '/dashboard/research-profile/requests' }
        .not_to change(Enact::ProfileRequest, :count)
    end

    it 'refuses when the user already has a profile' do
      ada.update!(user:)
      expect { post '/dashboard/research-profile/requests' }
        .not_to change(Enact::ProfileRequest, :count)
    end

    it 'rejects an anonymous request' do
      logout(:user)
      expect { post '/dashboard/research-profile/requests' }
        .not_to change(Enact::ProfileRequest, :count)
    end
  end

  describe 'POST /contributors/:id/claim' do
    before { login_as(user, scope: :user) }

    it 'creates a request naming the contributor to claim' do
      expect { post "/contributors/#{ada.id}/claim" }
        .to change(Enact::ProfileRequest, :count).by(1)
      expect(Enact::ProfileRequest.last.contributor).to eq(ada)
      expect(Enact::ProfileRequest.last).to be_claim
    end

    it 'carries the note from the claim modal through to the reviewer' do
      post "/contributors/#{ada.id}/claim", params: { profile_request: { note: 'I deposited this in 2019.' } }
      expect(Enact::ProfileRequest.last.note).to eq('I deposited this in 2019.')
    end

    it 'refuses to claim a profile another user already holds' do
      ada.update!(user: FactoryBot.create(:user))
      expect { post "/contributors/#{ada.id}/claim" }
        .not_to change(Enact::ProfileRequest, :count)
    end
  end

  describe 'DELETE /dashboard/research-profile/requests/:id (withdraw)' do
    it 'withdraws the user’s own pending request' do
      request = Enact::ProfileRequest.create!(user:)
      login_as(user, scope: :user)
      expect { delete "/dashboard/research-profile/requests/#{request.id}" }
        .to change(Enact::ProfileRequest, :count).by(-1)
    end

    it 'cannot withdraw another users request' do
      request = Enact::ProfileRequest.create!(user:)
      login_as(FactoryBot.create(:user), scope: :user)
      expect { delete "/dashboard/research-profile/requests/#{request.id}" }
        .not_to change(Enact::ProfileRequest, :count)
    end
  end

  describe 'the claim prompt on a contributor profile' do
    it 'invites a signed-in user with no profile to claim an unclaimed one' do
      login_as(user, scope: :user)
      get "/contributors/#{ada.id}"
      expect(response.body).to include('Is this you?')
    end

    # No CTA that only leads to a login wall.
    it 'is absent for an anonymous visitor' do
      get "/contributors/#{ada.id}"
      expect(response.body).not_to include('Is this you?')
    end

    it 'is absent once the profile is claimed' do
      ada.update!(user: FactoryBot.create(:user))
      login_as(user, scope: :user)
      get "/contributors/#{ada.id}"
      expect(response.body).not_to include('Is this you?')
    end

    it 'is absent when the user already has a request open' do
      Enact::ProfileRequest.create!(user:)
      login_as(user, scope: :user)
      get "/contributors/#{ada.id}"
      expect(response.body).not_to include('Is this you?')
    end

    it 'is absent when the user already has a profile' do
      Enact::Contributor.create!(display_name: 'Their Own', user:)
      login_as(user, scope: :user)
      get "/contributors/#{ada.id}"
      expect(response.body).not_to include('Is this you?')
    end
  end
end
