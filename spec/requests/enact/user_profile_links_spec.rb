# frozen_string_literal: true

require 'rails_helper'

# The admin side of research-profile linking: a demand-driven worklist of users
# who asked for a profile.
RSpec.describe 'Enact research profile linking (admin)', type: :request, singletenant: true do
  let(:admin) { FactoryBot.create(:admin) }
  let(:user) { FactoryBot.create(:user) }

  def worklist_path(params = {})
    query = params.compact.map { |k, v| "#{k}=#{v}" }.join('&')
    query.present? ? "/dashboard/research-profiles?#{query}" : '/dashboard/research-profiles'
  end

  describe 'GET /dashboard/research-profiles (worklist)' do
    it 'is closed to anonymous visitors' do
      get worklist_path
      expect(response).not_to have_http_status(:ok)
    end

    it 'is closed to a signed-in non-admin' do
      login_as(user, scope: :user)
      get worklist_path
      expect(response).not_to have_http_status(:ok)
    end

    context 'as an admin' do
      before { login_as(admin, scope: :user) }

      it 'lists requesters, unlinked users and linked users together' do
        requester = FactoryBot.create(:user)
        Enact::ProfileRequest.create!(user: requester)
        unlinked = FactoryBot.create(:user)
        linked = FactoryBot.create(:user)
        Enact::Contributor.create!(display_name: 'Ada', user: linked)

        get worklist_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(requester.email)
        expect(response.body).to include(unlinked.email)
        expect(response.body).to include(linked.email)
      end

      it 'offers the action each group can take' do
        requester = FactoryBot.create(:user)
        Enact::ProfileRequest.create!(user: requester)
        linked = FactoryBot.create(:user)
        Enact::Contributor.create!(display_name: 'Ada', user: linked)
        FactoryBot.create(:user)

        get worklist_path
        expect(response.body).to include('Review')
        expect(response.body).to include('Link')
        expect(response.body).to include('Unlink')
      end

      it 'filters by email or display name' do
        match = FactoryBot.create(:user, display_name: 'Ada Lovelace')
        other = FactoryBot.create(:user, display_name: 'Grace Hopper')
        get worklist_path(q: 'Lovelace')
        expect(response.body).to include(match.email)
        expect(response.body).not_to include(other.email)
      end

      it 'shows the profile a claim request names' do
        contributor = Enact::Contributor.create!(display_name: 'Ada Lovelace')
        Enact::ProfileRequest.create!(user:, contributor:)
        get worklist_path
        expect(response.body).to include('Ada Lovelace')
      end

      it 'shows the profile a linked user holds' do
        linked = FactoryBot.create(:user)
        Enact::Contributor.create!(display_name: 'Grace Hopper', user: linked)
        get worklist_path
        expect(response.body).to include('Grace Hopper')
      end
    end
  end

  describe 'worklist ordering' do
    before { login_as(admin, scope: :user) }

    it 'orders requesters, then unlinked, then linked' do
      requester = FactoryBot.create(:user, email: 'zzz-requester@example.com')
      Enact::ProfileRequest.create!(user: requester)
      unlinked = FactoryBot.create(:user, email: 'mmm-unlinked@example.com')
      linked = FactoryBot.create(:user, email: 'aaa-linked@example.com')
      Enact::Contributor.create!(display_name: 'Ada', user: linked)

      get worklist_path
      body = response.body
      expect(body.index(requester.email)).to be < body.index(unlinked.email)
      expect(body.index(unlinked.email)).to be < body.index(linked.email)
    end

    it 'puts the oldest request first within the request group' do
      newer = FactoryBot.create(:user, email: 'aaa-newer@example.com')
      older = FactoryBot.create(:user, email: 'zzz-older@example.com')
      Enact::ProfileRequest.create!(user: older, created_at: 3.days.ago)
      Enact::ProfileRequest.create!(user: newer, created_at: 1.hour.ago)

      get worklist_path
      body = response.body
      expect(body.index(older.email)).to be < body.index(newer.email)
    end

    it 'keeps requesters on page 1 when they are alphabetically last' do
      25.times { |i| FactoryBot.create(:user, email: "aaa-#{format('%02d', i)}@example.com") }
      requester = FactoryBot.create(:user, email: 'zzz-last@example.com')
      Enact::ProfileRequest.create!(user: requester)

      get worklist_path
      expect(response.body).to include(requester.email)
    end
  end

  describe 'reaching the link screen the way the worklist links to it' do
    before { login_as(admin, scope: :user) }

    it 'finds the user from the path helper slug' do
      path = HykuKnapsack::Engine.routes.url_helpers.new_dashboard_research_profile_link_path(user)
      get path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(user.email)
    end

    it 'links from the path helper slug' do
      contributor = Enact::Contributor.create!(display_name: 'Ada Lovelace')
      path = HykuKnapsack::Engine.routes.url_helpers.dashboard_research_profile_link_path(user)
      post path, params: { contributor_id: contributor.id }
      expect(contributor.reload.user).to eq(user)
    end
  end

  describe 'GET /dashboard/research-profiles/:user_id/link' do
    before { login_as(admin, scope: :user) }

    it 'leads with the profile the user asked to claim' do
      claimed = Enact::Contributor.create!(display_name: 'Zzz Unrelated Name')
      Enact::ProfileRequest.create!(user:, contributor: claimed)

      get "/dashboard/research-profiles/#{user.id}/link"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Zzz Unrelated Name')
      expect(response.body).to include('asked to claim')
    end

    it 'shows prior declines with their reason' do
      Enact::ProfileRequest.create!(user:)
                           .decline!(by: admin, note: 'Could not verify identity.')
      Enact::ProfileRequest.create!(user:)

      get "/dashboard/research-profiles/#{user.id}/link"
      expect(response.body).to include('Could not verify identity.')
    end

    it 'says nothing about declines when there are none' do
      Enact::ProfileRequest.create!(user:)
      get "/dashboard/research-profiles/#{user.id}/link"
      expect(response.body).not_to include('Declined before')
    end

    it 'offers a decline form when a request is pending' do
      Enact::ProfileRequest.create!(user:, note: 'I deposit under Ada L.')
      get "/dashboard/research-profiles/#{user.id}/link"
      expect(response.body).to include('Reason for declining')
      expect(response.body).to include('I deposit under Ada L.')
    end

    it 'offers no decline form when nothing is pending' do
      get "/dashboard/research-profiles/#{user.id}/link"
      expect(response.body).not_to include('Reason for declining')
    end

    it 'declines from the review page' do
      request = Enact::ProfileRequest.create!(user:)
      post "/dashboard/research-profiles/requests/#{request.id}/decline",
           params: { profile_request: { review_note: 'Could not verify identity.' } }

      expect(request.reload).to be_declined
      expect(request.review_note).to eq('Could not verify identity.')
    end

    it 'does not treat an earlier approval as a decline' do
      Enact::ProfileRequest.create!(user:).approve!(by: admin)
      get "/dashboard/research-profiles/#{user.id}/link"
      expect(response.body).not_to include('Declined before')
    end

    it 'surfaces an exact ORCID match above the fuzzy suggestions' do
      orcid = 'https://orcid.org/0000-0001-2345-6789'
      user.update!(orcid:, display_name: 'A. Lovelace')
      exact = Enact::Contributor.create!(display_name: 'Completely Different', orcid:)
      Enact::Contributor.create!(display_name: 'A. Lovelace')

      get "/dashboard/research-profiles/#{user.id}/link"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(exact.display_name)
    end

    it 'suggests fuzzy name matches' do
      user.update!(display_name: 'Jon Smith')
      Enact::Contributor.create!(display_name: 'John Smith')

      get "/dashboard/research-profiles/#{user.id}/link"
      expect(response.body).to include('John Smith')
    end

    it 'searches all profiles on demand' do
      Enact::Contributor.create!(display_name: 'Grace Hopper')
      get "/dashboard/research-profiles/#{user.id}/link?q=Hopper"
      expect(response.body).to include('Grace Hopper')
    end

    it 'omits profiles another user already holds' do
      Enact::Contributor.create!(display_name: 'Grace Hopper', user: FactoryBot.create(:user))
      get "/dashboard/research-profiles/#{user.id}/link?q=Hopper"
      expect(response.body).not_to include('Grace Hopper')
    end

    it 'omits organizations, which cannot hold a user account' do
      Enact::Contributor.create!(display_name: 'Hopper Lab', agent_type: 'organization')
      get "/dashboard/research-profiles/#{user.id}/link?q=Hopper"
      expect(response.body).not_to include('Hopper Lab')
    end

    it 'omits an organization from the fuzzy suggestions' do
      user.update!(display_name: 'Acme Lab')
      Enact::Contributor.create!(display_name: 'Acme Labs', agent_type: 'organization')
      get "/dashboard/research-profiles/#{user.id}/link"
      expect(response.body).not_to include('Acme Labs')
    end

    it 'tolerates a typo in the search term' do
      Enact::Contributor.create!(display_name: 'John Smith')
      get "/dashboard/research-profiles/#{user.id}/link?q=Jon+Smith"
      expect(response.body).to include('John Smith')
    end

    it 'still finds a profile by affiliation substring' do
      contributor = Enact::Contributor.create!(display_name: 'Grace Hopper')
      contributor.update!(affiliations: ['Analytical Society'])
      get "/dashboard/research-profiles/#{user.id}/link?q=Analytical"
      expect(response.body).to include('Grace Hopper')
    end

    it 'redirects when the user already has a profile' do
      Enact::Contributor.create!(display_name: 'Ada', user:)
      get "/dashboard/research-profiles/#{user.id}/link"
      expect(response).to redirect_to(worklist_path)
    end
  end

  describe 'GET /dashboard/research-profiles/:user_id/profile/new (prefilled form)' do
    before { login_as(admin, scope: :user) }

    it 'prefills from the account own fields' do
      user.update!(display_name: 'Ada Lovelace',
                   orcid: 'https://orcid.org/0000-0001-2345-6789',
                   affiliation: 'Analytical Society')

      get "/dashboard/research-profiles/#{user.id}/profile/new"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Ada Lovelace')
      expect(response.body).to include('0000-0001-2345-6789')
      expect(response.body).to include('Analytical Society')
    end

    it 'is closed to a non-admin' do
      login_as(FactoryBot.create(:user), scope: :user)
      get "/dashboard/research-profiles/#{user.id}/profile/new"
      expect(response).not_to have_http_status(:ok)
    end
  end

  describe 'POST /dashboard/research-profiles/:user_id/link' do
    before { login_as(admin, scope: :user) }

    it 'links an existing profile' do
      contributor = Enact::Contributor.create!(display_name: 'Ada Lovelace')
      post "/dashboard/research-profiles/#{user.id}/link", params: { contributor_id: contributor.id }
      expect(contributor.reload.user).to eq(user)
    end

    it 'creates a profile from the submitted fields' do
      expect do
        post "/dashboard/research-profiles/#{user.id}/link",
             params: { contributor: { display_name: 'Ada Lovelace',
                                      orcid: 'https://orcid.org/0000-0001-2345-6789',
                                      agent_type: 'person',
                                      affiliations: 'Analytical Society' } }
      end.to change(Enact::Contributor, :count).by(1)

      contributor = Enact::Contributor.find_by(user_id: user.id)
      expect(contributor.display_name).to eq('Ada Lovelace')
      expect(contributor.orcid).to eq('https://orcid.org/0000-0001-2345-6789')
      expect(contributor.affiliations).to eq(['Analytical Society'])
    end

    it 'does not create a profile without submitted fields' do
      expect { post "/dashboard/research-profiles/#{user.id}/link" }
        .not_to change(Enact::Contributor, :count)
    end

    it 're-renders the form when the submitted name is blank' do
      expect do
        post "/dashboard/research-profiles/#{user.id}/link",
             params: { contributor: { display_name: '' } }
      end.not_to change(Enact::Contributor, :count)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'does not copy account contact fields into the profile' do
      user.update!(display_name: 'Ada', department: 'Computing', telephone: '555-0100',
                   website: 'https://example.com', title: 'Professor')
      post "/dashboard/research-profiles/#{user.id}/link",
           params: { contributor: { display_name: 'Ada' } }

      blob = Enact::Contributor.find_by(user_id: user.id).metadata.to_json
      expect(blob).not_to include('Computing')
      expect(blob).not_to include('555-0100')
      expect(blob).not_to include(user.email)
    end

    it 'approves the pending request in the same action' do
      request = Enact::ProfileRequest.create!(user:)
      post "/dashboard/research-profiles/#{user.id}/link",
           params: { contributor: { display_name: 'Ada Lovelace' } }
      expect(request.reload).to be_approved
      expect(request.reviewed_by).to eq(admin)
      expect(request.reviewed_at).to be_present
    end

    it 'refuses a profile another user already holds' do
      taken = Enact::Contributor.create!(display_name: 'Ada', user: FactoryBot.create(:user))
      post "/dashboard/research-profiles/#{user.id}/link", params: { contributor_id: taken.id }
      expect(taken.reload.user).not_to eq(user)
      expect(response).to redirect_to("/dashboard/research-profiles/#{user.to_param}/link")
    end

    it 'returns to the review page when the profile no longer exists' do
      post "/dashboard/research-profiles/#{user.id}/link", params: { contributor_id: 0 }
      expect(response).to redirect_to("/dashboard/research-profiles/#{user.to_param}/link")
    end

    it 're-renders the form when the submitted ORCID is already in use' do
      orcid = 'https://orcid.org/0000-0001-2345-6789'
      Enact::Contributor.create!(display_name: 'Existing', orcid:, user: FactoryBot.create(:user))
      user.update!(orcid:, display_name: 'Ada')

      expect do
        post "/dashboard/research-profiles/#{user.id}/link",
             params: { contributor: { display_name: 'Ada', orcid: } }
      end.not_to change(Enact::Contributor, :count)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'is closed to a non-admin' do
      login_as(user, scope: :user)
      contributor = Enact::Contributor.create!(display_name: 'Ada')
      post "/dashboard/research-profiles/#{user.id}/link", params: { contributor_id: contributor.id }
      expect(contributor.reload.user).to be_nil
    end
  end

  describe 'POST /dashboard/research-profiles/requests/:id/decline' do
    before { login_as(admin, scope: :user) }

    it 'records the decision without linking anything' do
      request = Enact::ProfileRequest.create!(user:)
      post "/dashboard/research-profiles/requests/#{request.id}/decline",
           params: { profile_request: { review_note: 'Could not verify identity.' } }

      expect(request.reload).to be_declined
      expect(request.reviewed_by).to eq(admin)
      expect(request.review_note).to eq('Could not verify identity.')
      expect(user.reload.enact_contributor).to be_nil
    end

    it 'requires a reason' do
      request = Enact::ProfileRequest.create!(user:)
      post "/dashboard/research-profiles/requests/#{request.id}/decline",
           params: { profile_request: { review_note: '   ' } }

      expect(request.reload).to be_pending
      expect(flash[:alert]).to be_present
    end

    it 'returns to the review page when the reason is blank' do
      request = Enact::ProfileRequest.create!(user:)
      post "/dashboard/research-profiles/requests/#{request.id}/decline",
           params: { profile_request: { review_note: '' } }

      expect(response).to redirect_to("/dashboard/research-profiles/#{user.to_param}/link")
    end

    it 'does not overwrite the requester note when no reason is given' do
      request = Enact::ProfileRequest.create!(user:, note: 'I deposit under Ada L.')
      post "/dashboard/research-profiles/requests/#{request.id}/decline",
           params: { profile_request: { review_note: '' } }

      expect(request.reload.note).to eq('I deposit under Ada L.')
    end

    it 'is closed to a non-admin' do
      request = Enact::ProfileRequest.create!(user:)
      login_as(FactoryBot.create(:user), scope: :user)
      post "/dashboard/research-profiles/requests/#{request.id}/decline"
      expect(request.reload).to be_pending
    end
  end

  describe 'unlinking' do
    let!(:contributor) { Enact::Contributor.create!(display_name: 'Ada Lovelace', user:) }

    before { login_as(admin, scope: :user) }

    # A profile is curated repository metadata crediting works — unlinking
    # releases the account, it must never delete the profile.
    it 'clears the link but keeps the profile' do
      delete "/dashboard/research-profiles/#{user.id}/link"
      expect(Enact::Contributor.exists?(contributor.id)).to be(true)
      expect(contributor.reload.user_id).to be_nil
    end

    it 'works from the contributor side too' do
      delete "/contributors/#{contributor.id}/link"
      expect(contributor.reload.user_id).to be_nil
      expect(Enact::Contributor.exists?(contributor.id)).to be(true)
    end

    it 'returns to the worklist when unlinked from there' do
      delete "/contributors/#{contributor.id}/link",
             headers: { 'HTTP_REFERER' => worklist_path }
      expect(response).to redirect_to(worklist_path)
      expect(flash[:notice]).to be_present
    end

    it 'stays on the profile when unlinked from the profile page' do
      delete "/contributors/#{contributor.id}/link",
             headers: { 'HTTP_REFERER' => "/contributors/#{contributor.id}" }
      expect(response).to redirect_to("/contributors/#{contributor.id}")
    end

    it 'is closed to a non-admin' do
      login_as(FactoryBot.create(:user), scope: :user)
      delete "/dashboard/research-profiles/#{user.id}/link"
      expect(contributor.reload.user_id).to eq(user.id)
    end
  end

  describe 'the linked-user panel on a profile page' do
    let!(:contributor) { Enact::Contributor.create!(display_name: 'Ada Lovelace') }

    it 'names the linked account by email on the unlink control for an admin' do
      contributor.update!(user:)
      login_as(admin, scope: :user)

      get "/contributors/#{contributor.id}"
      expect(response.body).to include('Unlink from')
      expect(response.body).to include(user.email)
    end

    it 'shows nothing to an anonymous visitor' do
      contributor.update!(user:)
      get "/contributors/#{contributor.id}"
      expect(response.body).not_to include('Unlink')
      expect(response.body).not_to include(user.email)
    end

    it 'shows nothing to a signed-in non-admin' do
      contributor.update!(user:)
      login_as(FactoryBot.create(:user), scope: :user)
      get "/contributors/#{contributor.id}"
      expect(response.body).not_to include('Unlink')
      expect(response.body).not_to include(user.email)
    end

    it 'says nothing about the linked account name' do
      user.update!(display_name: 'Ada Byron')
      contributor.update!(user:)
      login_as(admin, scope: :user)

      get "/contributors/#{contributor.id}"
      expect(response.body).not_to include('Ada Byron')
    end
  end
end
