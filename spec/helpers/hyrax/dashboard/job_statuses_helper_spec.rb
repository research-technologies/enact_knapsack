# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Hyrax::Dashboard::JobStatusesHelper, type: :helper do
  describe '#job_status_work_path' do
    it 'builds the concern show path from the works id and model' do
      work = { work_id: 'abc-123', model: 'PortfolioArtefact' }

      expect(helper.job_status_work_path(work)).to eq(main_app.hyrax_portfolio_artefact_path('abc-123'))
    end
  end

  describe '#job_status_file_set_path' do
    it 'builds the file set show path from the file set id' do
      file_set = { file_set_id: 'fs-456' }

      expect(helper.job_status_file_set_path(file_set)).to eq(main_app.hyrax_file_set_path('fs-456'))
    end
  end

  describe '#job_status_badge_class' do
    it 'maps each state to its accessible tint badge class, defaulting to queued' do
      expect(helper.job_status_badge_class('complete')).to eq('job-badge-complete')
      expect(helper.job_status_badge_class('running')).to eq('job-badge-running')
      expect(helper.job_status_badge_class('retrying')).to eq('job-badge-retrying')
      expect(helper.job_status_badge_class('failed')).to eq('job-badge-failed')
      expect(helper.job_status_badge_class('pending')).to eq('job-badge-queued')
    end
  end

  describe '#job_status_bar_class' do
    it 'animates in-progress bars, leaves pending empty, and fills the rest' do
      expect(helper.job_status_bar_class('running')).to eq('bg-info progress-bar-striped progress-bar-animated')
      expect(helper.job_status_bar_class('retrying')).to eq('bg-warning progress-bar-striped progress-bar-animated')
      expect(helper.job_status_bar_class('pending')).to eq('')
      expect(helper.job_status_bar_class('complete')).to eq('bg-success')
      expect(helper.job_status_bar_class('failed')).to eq('bg-danger')
    end
  end

  describe '#job_status_dot_class' do
    it 'is green when done, red-glow on failure, and amber while in progress (pulsing when active)' do
      expect(helper.job_status_dot_class('complete')).to eq('job-dot-done')
      expect(helper.job_status_dot_class('failed')).to eq('job-dot-error job-dot-error-glow')
      expect(helper.job_status_dot_class('running')).to eq('job-dot-active job-dot-pulse')
      expect(helper.job_status_dot_class('retrying')).to eq('job-dot-active job-dot-pulse')
      expect(helper.job_status_dot_class('pending')).to eq('job-dot-active')
    end
  end

  describe '#job_status_error' do
    it 'returns the stage error truncated to 200 characters' do
      stage = { error: 'x' * 300 }

      expect(helper.job_status_error(stage).length).to eq(200)
    end

    it 'returns nil when the stage has no error' do
      expect(helper.job_status_error(error: nil)).to be_nil
    end
  end
end
