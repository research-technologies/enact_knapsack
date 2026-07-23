# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Hyrax::Dashboard::JobStatusesController, type: :controller do
  let(:user) { FactoryBot.create(:user) }

  routes { HykuKnapsack::Engine.routes }

  before { allow(Flipflop).to receive(:job_statuses?).and_return(true) }

  context 'when signed in' do
    before { sign_in user }

    it 'assigns the current user jobs' do
      job = GoodJob::Job.create!(serialized_params: { 'tenant' => Apartment::Tenant.current, 'user_id' => user.id, 'job_class' => 'ValkyrieCreateDerivativesJob' })

      get :index

      expect(assigns(:user_jobs)).to contain_exactly(job)
    end
  end

  context 'when not signed in' do
    it 'redirects to sign in' do
      get :index

      expect(response).to have_http_status(:redirect)
    end
  end

  context 'when the feature is disabled' do
    before do
      sign_in user
      allow(Flipflop).to receive(:job_statuses?).and_return(false)
    end

    it 'redirects away instead of showing the page and alerts the user' do
      get :index

      expect(response).to have_http_status(:redirect)
      expect(flash[:alert]).to eq(I18n.t('enact.job_statuses.disabled'))
    end
  end
end
