# frozen_string_literal: true

require 'rails_helper'

# The dashboard sidebar entries this feature adds.
RSpec.describe 'Research profile dashboard navigation', type: :request, singletenant: true do
  let(:user) { FactoryBot.create(:user) }
  let(:admin) { FactoryBot.create(:admin) }

  describe 'the admin worklist item (beside Users and Groups)' do
    it 'is offered to an admin' do
      login_as(admin, scope: :user)
      get '/dashboard'
      expect(response.body).to include('/dashboard/research-profiles')
    end

    it 'is hidden from a non-admin' do
      login_as(user, scope: :user)
      get '/dashboard'
      expect(response.body).not_to include('/dashboard/research-profiles')
    end

    it 'badges the pending queue depth' do
      Enact::ProfileRequest.create!(user:)
      login_as(admin, scope: :user)
      get '/dashboard'
      expect(response.body).to include('/dashboard/research-profiles')
    end
  end

  describe 'the user’s own research profile item (Your activity)' do
    it 'is offered to any signed-in user' do
      login_as(user, scope: :user)
      get '/dashboard'
      expect(response.body).to include('/dashboard/research-profile"')
    end
  end
end
