# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Hyrax::Dashboard::JobStatusesController, type: :controller do
  let(:user) { FactoryBot.create(:user) }

  routes { HykuKnapsack::Engine.routes }

  before { allow(Flipflop).to receive(:job_statuses?).and_return(true) }

  context 'when signed in' do
    before { sign_in user }

    it 'assigns the current user jobs grouped under their work' do
      file_set = FactoryBot.valkyrie_create(:hyrax_file_set, label: 'in_n_out.mp4')
      FactoryBot.valkyrie_create(:hyrax_work, title: ['In N Out'], members: [file_set])
      GoodJob::Job.create!(serialized_params: {
                             'tenant' => Apartment::Tenant.current,
                             'user_id' => user.id,
                             'job_class' => 'ValkyrieCreateDerivativesJob',
                             'arguments' => [file_set.id.to_s, 'some-file-id']
                           })

      get :index

      expect(assigns(:works).map { |work| work[:title] }).to contain_exactly('In N Out')
    end

    context 'rendering the page' do
      render_views

      it 'links each work and file set to its show page' do
        file_set = FactoryBot.valkyrie_create(:hyrax_file_set, label: 'in_n_out.mp4')
        work = Hyrax.persister.save(resource: PortfolioArtefact.new(title: ['In N Out'], member_ids: [file_set.id]))
        Hyrax.index_adapter.save(resource: work)
        GoodJob::Job.create!(serialized_params: {
                               'tenant' => Apartment::Tenant.current,
                               'user_id' => user.id,
                               'job_class' => 'ValkyrieCreateDerivativesJob',
                               'arguments' => [file_set.id.to_s, 'some-file-id']
                             })

        get :index

        routes = Rails.application.routes.url_helpers
        expect(response.body).to include(routes.hyrax_file_set_path(file_set.id.to_s))
        expect(response.body).to include(routes.hyrax_portfolio_artefact_path(work.id.to_s))
      end

      it 'shows the failure reason for an errored stage' do
        file_set = FactoryBot.valkyrie_create(:hyrax_file_set, label: 'in_n_out.mp4')
        work = Hyrax.persister.save(resource: PortfolioArtefact.new(title: ['In N Out'], member_ids: [file_set.id]))
        Hyrax.index_adapter.save(resource: work)
        GoodJob::Job.create!(finished_at: Time.current, error: 'CharacterizationError: ffprobe failed', serialized_params: {
                               'tenant' => Apartment::Tenant.current,
                               'user_id' => user.id,
                               'job_class' => 'ValkyrieCreateDerivativesJob',
                               'arguments' => [file_set.id.to_s, 'some-file-id']
                             })

        get :index

        expect(response.body).to include('CharacterizationError: ffprobe failed')
      end

      it 'labels a job that errored but is scheduled to retry as Retrying' do
        file_set = FactoryBot.valkyrie_create(:hyrax_file_set, label: 'in_n_out.mp4')
        work = Hyrax.persister.save(resource: PortfolioArtefact.new(title: ['In N Out'], member_ids: [file_set.id]))
        Hyrax.index_adapter.save(resource: work)
        GoodJob::Job.create!(error: 'RuntimeError: fits down', scheduled_at: 1.hour.from_now, executions_count: 3, serialized_params: {
                               'tenant' => Apartment::Tenant.current,
                               'user_id' => user.id,
                               'job_class' => 'ValkyrieCreateDerivativesJob',
                               'arguments' => [file_set.id.to_s, 'some-file-id']
                             })

        get :index

        expect(response.body).to include('Retrying (attempt 3)')
        expect(response.body).not_to include('Pending')
      end

      it 'labels a job that exhausted its retries as Failed after the attempt count' do
        file_set = FactoryBot.valkyrie_create(:hyrax_file_set, label: 'in_n_out.mp4')
        work = Hyrax.persister.save(resource: PortfolioArtefact.new(title: ['In N Out'], member_ids: [file_set.id]))
        Hyrax.index_adapter.save(resource: work)
        GoodJob::Job.create!(finished_at: Time.current, error: 'RuntimeError: fits down', executions_count: 5, serialized_params: {
                               'tenant' => Apartment::Tenant.current,
                               'user_id' => user.id,
                               'job_class' => 'ValkyrieCreateDerivativesJob',
                               'arguments' => [file_set.id.to_s, 'some-file-id']
                             })

        get :index

        expect(response.body).to include('Failed after 5 attempts')
      end
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
