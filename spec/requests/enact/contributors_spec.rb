# frozen_string_literal: true

require 'rails_helper'

# The contributor browse index (linked from the home page Featured Researcher
# tab) and the individual profile show page. Public, no auth.
# :singletenant — routing is multitenancy-sensitive in Hyku; without it the
# bare `get '/contributors'` 404s because the request carries no tenant host.
RSpec.describe 'Enact contributors pages', type: :request, singletenant: true do
  let!(:ada) { Enact::Contributor.create!(display_name: 'Ada Lovelace', orcid: 'https://orcid.org/0000-0001-2345-6789') }
  let!(:acme) { Enact::Contributor.create!(display_name: 'Acme Lab', agent_type: 'organization') }

  describe 'GET /contributors (index)' do
    it 'lists contributors linking to their profiles' do
      get '/contributors'
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Ada Lovelace').and include('Acme Lab')
      expect(response.body).to include("/contributors/#{ada.id}")
    end

    it 'filters by free-text search on name / ORCID' do
      get '/contributors', params: { q: 'Ada' }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Ada Lovelace')
      expect(response.body).not_to include('Acme Lab')
    end

    it 'filters by agent_type' do
      get '/contributors', params: { agent_type: 'organization' }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Acme Lab')
      expect(response.body).not_to include('Ada Lovelace')
    end

    it 'shows a no-results message when a search matches nothing' do
      get '/contributors', params: { q: 'Nobody' }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('No research profiles match your search.')
    end

    it 'offers a reset link only when a filter is active' do
      get '/contributors'
      expect(response.body).not_to include('>Reset<')

      get '/contributors', params: { q: 'Ada' }
      expect(response.body).to include('>Reset<')
    end

    it 'renders pagination links when there is more than one page' do
      # 24 per page; create enough to spill onto a second page so the paginator
      # renders its page-link URLs for this engine-mounted route.
      30.times { |i| Enact::Contributor.create!(display_name: format('Pager %02d', i)) }
      get '/contributors'
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('/contributors?page=2')
    end

    it 'keeps the active filter in the pagination links' do
      30.times { |i| Enact::Contributor.create!(display_name: format('Org %02d', i), agent_type: 'organization') }
      get '/contributors', params: { agent_type: 'organization' }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('agent_type=organization').and include('page=2')
    end
  end

  describe 'GET /contributors/:id (show)' do
    it 'renders the contributor profile' do
      get "/contributors/#{ada.id}"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Ada Lovelace')
      expect(response.body).to include(ada.orcid)
    end

    it 'shows a breadcrumb back to the research profiles index' do
      get "/contributors/#{ada.id}"
      expect(response.body).to include('breadcrumb')
      expect(response.body).to include('Research profiles')
      expect(response.body).to include('href="/contributors"')
    end

    context 'with works crediting the contributor' do
      let(:credit) do
        # `roles` carries the stored role codes; the show page resolves each to
        # its human label via Enact::ContributorRolesService.
        Enact::ContributorGraph::Credit.new(
          id: 'work-1', title: 'A Credited Work', path: '/concern/portfolios/work-1',
          roles: ['conceptualization', 'data-curation']
        )
      end

      before do
        allow_any_instance_of(Enact::ContributorGraph).to receive(:works).and_return([credit]) # rubocop:disable RSpec/AnyInstance
      end

      it 'lists each work linked to its show page with its role labels as badges' do
        get "/contributors/#{ada.id}"
        expect(response.body).to include('A Credited Work')
        expect(response.body).to include('/concern/portfolios/work-1')
        expect(response.body).to include('Conceptualization').and include('Data curation')
        expect(response.body).to include('enact-role-badge')
      end
    end

    context 'with many works (pagination + search + type filter)' do
      # 25 artefacts spill the list past the 10-per-page limit; one uniquely
      # titled event gives the title search and work-type filter something to
      # narrow on. The graph normally sorts by title; we stub it directly, so the
      # returned order is what the view paginates (Artwork 00..24, then the event).
      let(:works) do
        artefacts = Array.new(25) do |i|
          Enact::ContributorGraph::Credit.new(
            id: "art-#{i}", title: format('Artwork %02d', i),
            path: "/concern/portfolio_artefacts/art-#{i}",
            roles: [], type_label: 'Artefact', model: 'PortfolioArtefact'
          )
        end
        event = Enact::ContributorGraph::Credit.new(
          id: 'evt-1', title: 'Unique Zephyr Happening',
          path: '/concern/portfolio_events/evt-1',
          roles: [], type_label: 'Event', model: 'PortfolioEvent'
        )
        artefacts + [event]
      end

      before do
        allow_any_instance_of(Enact::ContributorGraph).to receive(:works).and_return(works) # rubocop:disable RSpec/AnyInstance
      end

      it 'paginates the works list at 10 per page' do
        get "/contributors/#{ada.id}"
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("/contributors/#{ada.id}?page=2")
        expect(response.body).to include('Artwork 00')      # first page
        expect(response.body).not_to include('Artwork 10')  # spilled to a later page
        # Count line orients the user: 25 artefacts + 1 event = 26 total.
        expect(response.body).to include('Showing 1-10 of 26 works')
      end

      it 'clamps an out-of-range page back to the last page' do
        # ?page=999 must not fall through to the empty "No works yet" state; it
        # clamps to the last page (26 works / 10 per page = 3 pages), whose tail
        # includes the event.
        get "/contributors/#{ada.id}", params: { page: 999 }
        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include('No works yet.')
        expect(response.body).to include('Unique Zephyr Happening')
      end

      it 'narrows the list by a title substring search' do
        get "/contributors/#{ada.id}", params: { q: 'Zephyr' }
        expect(response.body).to include('Unique Zephyr Happening')
        expect(response.body).not_to include('Artwork 00')
      end

      it 'narrows the list by work type' do
        get "/contributors/#{ada.id}", params: { work_type: 'PortfolioEvent' }
        expect(response.body).to include('Unique Zephyr Happening')
        expect(response.body).not_to include('Artwork 00')
      end

      it 'keeps the active filter in the pagination links' do
        get "/contributors/#{ada.id}", params: { work_type: 'PortfolioArtefact' }
        expect(response.body).to include('work_type=PortfolioArtefact').and include('page=2')
      end

      it 'offers a reset link only when a filter is active' do
        get "/contributors/#{ada.id}"
        expect(response.body).not_to include('>Reset<')

        get "/contributors/#{ada.id}", params: { q: 'Zephyr' }
        expect(response.body).to include('>Reset<')
      end
    end

    context 'with no works' do
      before do
        allow_any_instance_of(Enact::ContributorGraph).to receive(:works).and_return([]) # rubocop:disable RSpec/AnyInstance
      end

      it 'shows the empty-works message' do
        get "/contributors/#{ada.id}"
        expect(response.body).to include('No works yet.')
      end
    end
  end

  describe 'editing (admin-gated)' do
    context 'as an admin' do
      before { login_as(FactoryBot.create(:admin), scope: :user) }

      it 'renders the edit form' do
        get "/contributors/#{ada.id}/edit"
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Edit profile')
      end

      it 'updates the contributor and redirects to the profile' do
        patch "/contributors/#{ada.id}",
              params: { contributor: { display_name: 'Ada L.', orcid: ada.orcid, agent_type: 'person',
                                       affiliations: "Westminster\nAnalytical Society",
                                       name_identifiers: "0000000121032683 | ISNI\nhttps://ror.org/02mhbdp94 | ROR" } }
        expect(response).to redirect_to("/contributors/#{ada.id}")
        expect(ada.reload.display_name).to eq('Ada L.')
        expect(ada.affiliations).to eq(['Westminster', 'Analytical Society'])
        expect(ada.name_identifiers).to eq(
          [{ 'value' => '0000000121032683', 'scheme' => 'ISNI' },
           { 'value' => 'https://ror.org/02mhbdp94', 'scheme' => 'ROR' }]
        )
      end

      it 're-renders edit on validation failure (blank name)' do
        patch "/contributors/#{ada.id}", params: { contributor: { display_name: '' } }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(ada.reload.display_name).to eq('Ada Lovelace')
      end
    end

    context 'as a non-admin logged-in user' do
      before { login_as(create(:user), scope: :user) }

      it 'forbids editing and redirects to the public profile' do
        get "/contributors/#{ada.id}/edit"
        expect(response).to redirect_to("/contributors/#{ada.id}")
      end

      it 'forbids updating' do
        patch "/contributors/#{ada.id}", params: { contributor: { display_name: 'Hacked' } }
        expect(response).to redirect_to("/contributors/#{ada.id}")
        expect(ada.reload.display_name).to eq('Ada Lovelace')
      end
    end

    context 'as an anonymous visitor' do
      it 'does not allow editing' do
        get "/contributors/#{ada.id}/edit"
        expect(ada.reload.display_name).to eq('Ada Lovelace')
        expect(response).not_to have_http_status(:ok)
      end
    end
  end
end
