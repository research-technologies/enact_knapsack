# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HykuKnapsack::UserJobsPresenter do
  it 'does not blow up when one grouped file set is missing from the index alongside a live one' do
    live_file_set = FactoryBot.valkyrie_create(:hyrax_file_set, label: 'in_n_out.mp4')
    FactoryBot.valkyrie_create(:hyrax_work, title: ['In N Out'], members: [live_file_set])
    live_job = GoodJob::Job.create!(serialized_params: { 'job_class' => 'ValkyrieCreateDerivativesJob', 'arguments' => [live_file_set.id.to_s, 'some-file-id'] })
    orphan_job = GoodJob::Job.create!(serialized_params: { 'job_class' => 'ValkyrieCreateDerivativesJob', 'arguments' => ['missing-file-set-id', 'some-file-id'] })
    grouped = [
      { file_set_id: live_file_set.id.to_s, jobs: [live_job] },
      { file_set_id: 'missing-file-set-id', jobs: [orphan_job] }
    ]

    works = described_class.new(grouped:).works

    expect(works.map { |work| work[:title] }).to contain_exactly('In N Out')
  end

  it 'returns no works and does not query Solr when there are no jobs' do
    expect(Hyrax::SolrService).not_to receive(:query)

    expect(described_class.new(grouped: []).works).to eq([])
  end

  it 'rolls file set groups up under their work with the work title' do
    file_set_a = FactoryBot.valkyrie_create(:hyrax_file_set)
    file_set_b = FactoryBot.valkyrie_create(:hyrax_file_set)
    file_set_c = FactoryBot.valkyrie_create(:hyrax_file_set)
    FactoryBot.valkyrie_create(:hyrax_work, title: ['First Work'], members: [file_set_a, file_set_b])
    FactoryBot.valkyrie_create(:hyrax_work, title: ['Second Work'], members: [file_set_c])

    grouped = [
      { file_set_id: file_set_a.id.to_s, jobs: [] },
      { file_set_id: file_set_b.id.to_s, jobs: [] },
      { file_set_id: file_set_c.id.to_s, jobs: [] }
    ]

    works = described_class.new(grouped:).works

    expect(works.map { |work| work[:title] }).to contain_exactly('First Work', 'Second Work')

    first = works.find { |work| work[:title] == 'First Work' }
    second = works.find { |work| work[:title] == 'Second Work' }
    expect(first[:file_sets].map { |entry| entry[:file_set_id] }).to contain_exactly(file_set_a.id.to_s, file_set_b.id.to_s)
    expect(second[:file_sets].map { |entry| entry[:file_set_id] }).to contain_exactly(file_set_c.id.to_s)
  end

  it 'labels each file set entry with its own file set label' do
    file_set_mp3 = FactoryBot.valkyrie_create(:hyrax_file_set, label: 'in_n_out.mp3')
    file_set_mp4 = FactoryBot.valkyrie_create(:hyrax_file_set, label: 'in_n_out.mp4')
    FactoryBot.valkyrie_create(:hyrax_work, title: ['In N Out'], members: [file_set_mp3, file_set_mp4])

    grouped = [
      { file_set_id: file_set_mp3.id.to_s, jobs: [] },
      { file_set_id: file_set_mp4.id.to_s, jobs: [] }
    ]

    file_sets = described_class.new(grouped:).works.first[:file_sets]

    labels = file_sets.to_h { |entry| [entry[:file_set_id], entry[:label]] }
    expect(labels).to eq(
      file_set_mp3.id.to_s => 'in_n_out.mp3',
      file_set_mp4.id.to_s => 'in_n_out.mp4'
    )
  end

  it 'falls back to a placeholder when the work has no title' do
    file_set = FactoryBot.valkyrie_create(:hyrax_file_set, label: 'in_n_out.mp4')
    FactoryBot.valkyrie_create(:hyrax_work, members: [file_set])

    grouped = [{ file_set_id: file_set.id.to_s, jobs: [] }]

    expect(described_class.new(grouped:).works.first[:title]).to eq('Untitled')
  end

  it 'falls back to a placeholder when the file set has no label' do
    file_set = FactoryBot.valkyrie_create(:hyrax_file_set)
    FactoryBot.valkyrie_create(:hyrax_work, title: ['In N Out'], members: [file_set])

    grouped = [{ file_set_id: file_set.id.to_s, jobs: [] }]

    expect(described_class.new(grouped:).works.first[:file_sets].first[:label]).to eq('Untitled')
  end

  it 'counts completed and total jobs per file set' do
    file_set = FactoryBot.valkyrie_create(:hyrax_file_set, label: 'in_n_out.mp4')
    FactoryBot.valkyrie_create(:hyrax_work, title: ['In N Out'], members: [file_set])

    succeeded = GoodJob::Job.create!(finished_at: Time.current, serialized_params: { 'job_class' => 'ValkyrieIngestJob' })
    also_succeeded = GoodJob::Job.create!(finished_at: Time.current, serialized_params: { 'job_class' => 'ValkyrieCharacterizationJob' })
    running = GoodJob::Job.create!(performed_at: Time.current, serialized_params: { 'job_class' => 'ValkyrieCreateDerivativesJob' })

    grouped = [{ file_set_id: file_set.id.to_s, jobs: [succeeded, also_succeeded, running] }]

    entry = described_class.new(grouped:).works.first[:file_sets].first
    expect(entry[:total]).to eq(3)
    expect(entry[:completed]).to eq(2)
  end

  it 'counts completed and total file sets per work, counting file sets with no jobs toward the total' do
    done_file_set = FactoryBot.valkyrie_create(:hyrax_file_set, label: 'done.mp4')
    pending_file_set = FactoryBot.valkyrie_create(:hyrax_file_set, label: 'pending.mp4')
    FactoryBot.valkyrie_create(:hyrax_work, title: ['Mixed Work'], members: [done_file_set, pending_file_set])

    finished = GoodJob::Job.create!(finished_at: Time.current, serialized_params: { 'job_class' => 'ValkyrieIngestJob' })
    grouped = [{ file_set_id: done_file_set.id.to_s, jobs: [finished] }]

    work = described_class.new(grouped:).works.first
    expect(work[:total]).to eq(2)
    expect(work[:completed]).to eq(1)
  end

  it 'lists each file set stage in run order oldest first' do
    file_set = FactoryBot.valkyrie_create(:hyrax_file_set, label: 'in_n_out.mp4')
    FactoryBot.valkyrie_create(:hyrax_work, title: ['In N Out'], members: [file_set])

    ingest = GoodJob::Job.create!(created_at: 3.minutes.ago, serialized_params: { 'job_class' => 'ValkyrieIngestJob' })
    characterize = GoodJob::Job.create!(created_at: 2.minutes.ago, serialized_params: { 'job_class' => 'ValkyrieCharacterizationJob' })
    derivative = GoodJob::Job.create!(created_at: 1.minute.ago, serialized_params: { 'job_class' => 'ValkyrieCreateLargeDerivativesJob' })

    grouped = [{ file_set_id: file_set.id.to_s, jobs: [derivative, characterize, ingest] }]

    entry = described_class.new(grouped:).works.first[:file_sets].first

    expect(entry[:stages].map { |stage| stage[:label] }).to eq(
      %w[ValkyrieIngestJob ValkyrieCharacterizationJob ValkyrieCreateLargeDerivativesJob]
    )
  end

  it 'orders works with the most recently modified first' do
    older_file_set = FactoryBot.valkyrie_create(:hyrax_file_set)
    newer_file_set = FactoryBot.valkyrie_create(:hyrax_file_set)
    FactoryBot.valkyrie_create(:hyrax_work, title: ['Older Work'], members: [older_file_set])
    FactoryBot.valkyrie_create(:hyrax_work, title: ['Newer Work'], members: [newer_file_set])

    grouped = [
      { file_set_id: older_file_set.id.to_s, jobs: [GoodJob::Job.create!(serialized_params: { 'job_class' => 'ValkyrieIngestJob' })] },
      { file_set_id: newer_file_set.id.to_s, jobs: [GoodJob::Job.create!(serialized_params: { 'job_class' => 'ValkyrieIngestJob' })] }
    ]

    works = described_class.new(grouped:).works

    expect(works.map { |work| work[:title] }).to eq(['Newer Work', 'Older Work'])
  end

  describe '.stage_for' do
    it 'maps a succeeded job to a Complete success badge' do
      job = GoodJob::Job.create!(finished_at: Time.current, executions_count: 1, serialized_params: { 'job_class' => 'ValkyrieCreateLargeDerivativesJob' })

      expect(described_class.stage_for(job)).to eq(label: 'ValkyrieCreateLargeDerivativesJob', name: 'Derivative', status: :succeeded, error: nil, attempts: 1, status_label: 'Complete',
                                                   variant: :success)
    end

    it 'maps a running job to a Running primary badge' do
      job = GoodJob::Job.create!(performed_at: Time.current, executions_count: 1, serialized_params: { 'job_class' => 'ValkyrieCharacterizationJob' })

      expect(described_class.stage_for(job)).to eq(label: 'ValkyrieCharacterizationJob', name: 'Characterize', status: :running, error: nil, attempts: 1, status_label: 'Running', variant: :primary)
    end

    it 'maps a queued job to a Pending secondary badge' do
      job = GoodJob::Job.create!(executions_count: 0, serialized_params: { 'job_class' => 'ValkyrieCharacterizationJob' })

      expect(described_class.stage_for(job)).to eq(label: 'ValkyrieCharacterizationJob', name: 'Characterize', status: :queued, error: nil, attempts: 0, status_label: 'Pending', variant: :secondary)
    end

    it 'maps a retrying job to a Retrying warning badge with the attempt count' do
      job = GoodJob::Job.create!(error: 'RuntimeError: fits down', scheduled_at: 1.hour.from_now, executions_count: 3, serialized_params: { 'job_class' => 'ValkyrieCharacterizationJob' })

      expect(described_class.stage_for(job)).to eq(label: 'ValkyrieCharacterizationJob', name: 'Characterize', status: :retried, error: 'RuntimeError: fits down', attempts: 3,
                                                   status_label: 'Retrying (attempt 3)', variant: :warning)
    end

    it 'maps a discarded job to a Failed danger badge with the attempt count' do
      job = GoodJob::Job.create!(finished_at: Time.current, error: 'CharacterizationError: ffprobe failed', executions_count: 5, serialized_params: { 'job_class' => 'ValkyrieCharacterizationJob' })

      expect(described_class.stage_for(job)).to eq(label: 'ValkyrieCharacterizationJob', name: 'Characterize', status: :discarded, error: 'CharacterizationError: ffprobe failed', attempts: 5,
                                                   status_label: 'Failed after 5 attempts', variant: :danger)
    end

    it 'gives each job class a friendly stage name' do
      names = {
        'ValkyrieIngestJob' => 'Ingest',
        'ValkyrieCharacterizationJob' => 'Characterize',
        'ValkyrieCreateDerivativesJob' => 'Derivative',
        'ValkyrieCreateLargeDerivativesJob' => 'Derivative'
      }

      names.each do |job_class, name|
        job = GoodJob::Job.create!(serialized_params: { 'job_class' => job_class })
        expect(described_class.stage_for(job)[:name]).to eq(name)
      end
    end
  end
end
