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

  it 'does not mark a work complete while a member file set has no jobs yet' do
    done_file_set = FactoryBot.valkyrie_create(:hyrax_file_set, label: 'done.mp4')
    untracked_file_set = FactoryBot.valkyrie_create(:hyrax_file_set, label: 'untracked.mp4')
    FactoryBot.valkyrie_create(:hyrax_work, title: ['Half Done'], members: [done_file_set, untracked_file_set])

    finished = GoodJob::Job.create!(finished_at: Time.current, serialized_params: { 'job_class' => 'ValkyrieIngestJob' })
    grouped = [{ file_set_id: done_file_set.id.to_s, jobs: [finished] }]

    work = described_class.new(grouped:).works.first
    expect(work[:state]).to eq('pending')
    expect(work[:open]).to be(true)
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

  it 'derives each file set state from its stages, with failure taking precedence' do
    failed_fs = FactoryBot.valkyrie_create(:hyrax_file_set, label: 'bad.mp4')
    done_fs = FactoryBot.valkyrie_create(:hyrax_file_set, label: 'good.jpg')
    FactoryBot.valkyrie_create(:hyrax_work, title: ['Mixed'], members: [failed_fs, done_fs])

    ingest = GoodJob::Job.create!(finished_at: Time.current, serialized_params: { 'job_class' => 'ValkyrieIngestJob' })
    char_failed = GoodJob::Job.create!(finished_at: Time.current, error: 'boom', executions_count: 5, serialized_params: { 'job_class' => 'ValkyrieCharacterizationJob' })
    char_done = GoodJob::Job.create!(finished_at: Time.current, serialized_params: { 'job_class' => 'ValkyrieCharacterizationJob' })

    grouped = [
      { file_set_id: failed_fs.id.to_s, jobs: [ingest, char_failed] },
      { file_set_id: done_fs.id.to_s, jobs: [ingest, char_done] }
    ]

    file_sets = described_class.new(grouped:).works.first[:file_sets]

    states = file_sets.to_h { |file_set| [file_set[:label], file_set[:state]] }
    expect(states).to eq('bad.mp4' => 'failed', 'good.jpg' => 'complete')
  end

  it 'flags a work whose file set failed and reports percent complete by file set' do
    failed_fs = FactoryBot.valkyrie_create(:hyrax_file_set, label: 'bad.mp4')
    done_fs = FactoryBot.valkyrie_create(:hyrax_file_set, label: 'good.jpg')
    FactoryBot.valkyrie_create(:hyrax_work, title: ['Mixed'], members: [failed_fs, done_fs])

    ingest = GoodJob::Job.create!(finished_at: Time.current, serialized_params: { 'job_class' => 'ValkyrieIngestJob' })
    failed = GoodJob::Job.create!(finished_at: Time.current, error: 'boom', executions_count: 5, serialized_params: { 'job_class' => 'ValkyrieCharacterizationJob' })

    grouped = [
      { file_set_id: failed_fs.id.to_s, jobs: [failed] },
      { file_set_id: done_fs.id.to_s, jobs: [ingest] }
    ]

    work = described_class.new(grouped:).works.first

    expect(work[:has_error]).to be(true)
    expect(work[:pct]).to eq(50)
  end

  it 'opens everything except complete items by default, so running, failed, and pending stay expanded' do
    running_fs = FactoryBot.valkyrie_create(:hyrax_file_set, label: 'running.mp4')
    pending_fs = FactoryBot.valkyrie_create(:hyrax_file_set, label: 'pending.tif')
    done_fs = FactoryBot.valkyrie_create(:hyrax_file_set, label: 'done.jpg')
    FactoryBot.valkyrie_create(:hyrax_work, title: ['In Progress'], members: [running_fs, pending_fs, done_fs])

    running = GoodJob::Job.create!(performed_at: Time.current, serialized_params: { 'job_class' => 'ValkyrieCharacterizationJob' })
    pending = GoodJob::Job.create!(executions_count: 0, serialized_params: { 'job_class' => 'ValkyrieIngestJob' })
    done = GoodJob::Job.create!(finished_at: Time.current, serialized_params: { 'job_class' => 'ValkyrieIngestJob' })

    grouped = [
      { file_set_id: running_fs.id.to_s, jobs: [running] },
      { file_set_id: pending_fs.id.to_s, jobs: [pending] },
      { file_set_id: done_fs.id.to_s, jobs: [done] }
    ]

    work = described_class.new(grouped:).works.first
    open_by_label = work[:file_sets].to_h { |file_set| [file_set[:label], file_set[:open]] }

    expect(work[:open]).to be(true)
    expect(open_by_label).to eq('running.mp4' => true, 'pending.tif' => true, 'done.jpg' => false)
  end

  describe '.stage_for' do
    it 'maps a succeeded job to a complete stage' do
      job = GoodJob::Job.create!(finished_at: Time.current, executions_count: 1, serialized_params: { 'job_class' => 'ValkyrieCreateLargeDerivativesJob' })

      stage = described_class.stage_for(job)

      expect(stage[:state]).to eq('complete')
    end

    it 'maps a running job to running and a retrying job to retrying, keeping the retry error' do
      running = GoodJob::Job.create!(performed_at: Time.current, serialized_params: { 'job_class' => 'ValkyrieCharacterizationJob' })
      retrying = GoodJob::Job.create!(error: 'RuntimeError: fits down', scheduled_at: 1.hour.from_now, executions_count: 3, serialized_params: { 'job_class' => 'ValkyrieCharacterizationJob' })

      expect(described_class.stage_for(running)[:state]).to eq('running')

      retry_stage = described_class.stage_for(retrying)
      expect(retry_stage[:state]).to eq('retrying')
      expect(retry_stage[:error]).to eq('RuntimeError: fits down')
      expect(retry_stage[:meta]).to eq('Attempt 3')
    end

    it 'maps a queued job to a pending stage' do
      job = GoodJob::Job.create!(executions_count: 0, serialized_params: { 'job_class' => 'ValkyrieCharacterizationJob' })

      expect(described_class.stage_for(job)[:state]).to eq('pending')
    end

    it 'maps a discarded job to a failed stage carrying its error' do
      job = GoodJob::Job.create!(finished_at: Time.current, error: 'CharacterizationError: ffprobe failed', executions_count: 5, serialized_params: { 'job_class' => 'ValkyrieCharacterizationJob' })

      stage = described_class.stage_for(job)

      expect(stage[:state]).to eq('failed')
      expect(stage[:error]).to eq('CharacterizationError: ffprobe failed')
    end

    it 'labels meta by state: finished, started, failed, or nothing when pending' do
      complete = GoodJob::Job.create!(finished_at: Time.current, serialized_params: { 'job_class' => 'ValkyrieIngestJob' })
      running = GoodJob::Job.create!(performed_at: Time.current, serialized_params: { 'job_class' => 'ValkyrieIngestJob' })
      failed = GoodJob::Job.create!(finished_at: Time.current, error: 'boom', executions_count: 5, serialized_params: { 'job_class' => 'ValkyrieIngestJob' })
      pending = GoodJob::Job.create!(executions_count: 0, serialized_params: { 'job_class' => 'ValkyrieIngestJob' })

      expect(described_class.stage_for(complete)[:meta]).to start_with('Finished ')
      expect(described_class.stage_for(running)[:meta]).to start_with('Started ')
      expect(described_class.stage_for(failed)[:meta]).to start_with('Failed ')
      expect(described_class.stage_for(pending)[:meta]).to be_nil
    end

    it 'reports how long a completed stage took' do
      job = GoodJob::Job.create!(performed_at: Time.utc(2024, 1, 1, 12, 0, 0), finished_at: Time.utc(2024, 1, 1, 12, 0, 38), serialized_params: { 'job_class' => 'ValkyrieIngestJob' })

      expect(described_class.stage_for(job)[:elapsed]).to eq('38s')
    end

    it 'reports a sub-second stage as less than a second' do
      job = GoodJob::Job.create!(performed_at: Time.utc(2024, 1, 1, 12, 0, 0), finished_at: Time.utc(2024, 1, 1, 12, 0, 0.4), serialized_params: { 'job_class' => 'ValkyrieIngestJob' })

      expect(described_class.stage_for(job)[:elapsed]).to eq('less than 1s')
    end

    it 'leaves elapsed nil on a stage that has not finished' do
      job = GoodJob::Job.create!(performed_at: Time.current, serialized_params: { 'job_class' => 'ValkyrieIngestJob' })

      expect(described_class.stage_for(job)[:elapsed]).to be_nil
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
