# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Hyrax::Dashboard::JobStatusesController, type: :controller do
  let(:user) { FactoryBot.create(:user) }

  before { routes.draw { get 'job_statuses', to: 'hyrax/dashboard/job_statuses#index' } }
  after { Rails.application.reload_routes! }

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
end
