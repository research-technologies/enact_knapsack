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
