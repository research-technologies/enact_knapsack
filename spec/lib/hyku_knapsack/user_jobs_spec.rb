# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HykuKnapsack::UserJobs do
  let(:user) { FactoryBot.create(:user) }
  let(:other) { FactoryBot.create(:user) }
  let(:tenant) { Apartment::Tenant.current }

  it 'returns only the given user jobs in the current tenant' do
    mine = GoodJob::Job.create!(serialized_params: { 'tenant' => tenant, 'user_id' => user.id, 'job_class' => 'ValkyrieCreateDerivativesJob' })
    GoodJob::Job.create!(serialized_params: { 'tenant' => tenant, 'user_id' => other.id, 'job_class' => 'ValkyrieCreateDerivativesJob' })

    expect(HykuKnapsack::UserJobs.for(user)).to contain_exactly(mine)
  end

  it 'returns the meaningful job classes and excludes noise' do
    kept = %w[ValkyrieIngestJob ValkyrieCharacterizationJob ValkyrieCreateDerivativesJob ValkyrieCreateLargeDerivativesJob].map do |klass|
      GoodJob::Job.create!(serialized_params: { 'tenant' => tenant, 'user_id' => user.id, 'job_class' => klass })
    end
    GoodJob::Job.create!(serialized_params: { 'tenant' => tenant, 'user_id' => user.id, 'job_class' => 'ContentUpdateEventJob' })

    expect(HykuKnapsack::UserJobs.for(user)).to match_array(kept)
  end

  it 'excludes jobs from other tenants with the same user id' do
    mine = GoodJob::Job.create!(serialized_params: { 'tenant' => tenant, 'user_id' => user.id, 'job_class' => 'ValkyrieCreateDerivativesJob' })
    GoodJob::Job.create!(serialized_params: { 'tenant' => 'some-other-tenant', 'user_id' => user.id, 'job_class' => 'ValkyrieCreateDerivativesJob' })

    expect(HykuKnapsack::UserJobs.for(user)).to contain_exactly(mine)
  end

  it 'returns the most recent jobs first' do
    newer = GoodJob::Job.create!(created_at: 1.hour.ago, serialized_params: { 'tenant' => tenant, 'user_id' => user.id, 'job_class' => 'ValkyrieCreateDerivativesJob' })
    older = GoodJob::Job.create!(created_at: 2.hours.ago, serialized_params: { 'tenant' => tenant, 'user_id' => user.id, 'job_class' => 'ValkyrieCreateDerivativesJob' })

    expect(HykuKnapsack::UserJobs.for(user).to_a).to eq([newer, older])
  end

  describe '.file_set_id_for' do
    let(:file_set) { FactoryBot.valkyrie_create(:hyrax_file_set) }

    it 'reads the file set id from a derivatives job first argument' do
      job = GoodJob::Job.create!(serialized_params: {
                                   'job_class' => 'ValkyrieCreateDerivativesJob',
                                   'arguments' => [file_set.id.to_s, 'some-file-id']
                                 })

      expect(HykuKnapsack::UserJobs.file_set_id_for(job)).to eq(file_set.id.to_s)
    end

    it 'resolves the file set id through the file metadata for a characterization job' do
      file_metadata = FactoryBot.valkyrie_create(:hyrax_file_metadata, file_set_id: file_set.id)
      job = GoodJob::Job.create!(serialized_params: {
                                   'job_class' => 'ValkyrieCharacterizationJob',
                                   'arguments' => [file_metadata.id.to_s]
                                 })

      expect(HykuKnapsack::UserJobs.file_set_id_for(job)).to eq(file_set.id.to_s)
    end

    it 'returns nil when the characterization job file metadata no longer exists' do
      job = GoodJob::Job.create!(serialized_params: {
                                   'job_class' => 'ValkyrieCharacterizationJob',
                                   'arguments' => ['deleted-file-metadata-id']
                                 })

      expect(HykuKnapsack::UserJobs.file_set_id_for(job)).to be_nil
    end

    it 'resolves the file set id through the uploaded file for an ingest job' do
      uploaded_file = Hyrax::UploadedFile.create!(user:, file_set_uri: file_set.id.to_s)
      job = GoodJob::Job.create!(serialized_params: {
                                   'job_class' => 'ValkyrieIngestJob',
                                   'arguments' => [{ '_aj_globalid' => uploaded_file.to_global_id.to_s }]
                                 })

      expect(HykuKnapsack::UserJobs.file_set_id_for(job)).to eq(file_set.id.to_s)
    end

    it 'returns nil when the ingest job uploaded file no longer exists' do
      job = GoodJob::Job.create!(serialized_params: {
                                   'job_class' => 'ValkyrieIngestJob',
                                   'arguments' => [{ '_aj_globalid' => 'gid://hyku/Hyrax::UploadedFile/999999' }]
                                 })

      expect(HykuKnapsack::UserJobs.file_set_id_for(job)).to be_nil
    end
  end

  describe '.grouped_for' do
    it "groups a user's jobs by file set id, collapsing jobs for the same file set" do
      file_set_a = FactoryBot.valkyrie_create(:hyrax_file_set)
      metadata_a = FactoryBot.valkyrie_create(:hyrax_file_metadata, file_set_id: file_set_a.id)
      other_file_set_id = 'file-set-b'

      deriv_a = GoodJob::Job.create!(serialized_params: { 'tenant' => tenant, 'user_id' => user.id, 'job_class' => 'ValkyrieCreateDerivativesJob',
                                                          'arguments' => [file_set_a.id.to_s, metadata_a.id.to_s] })
      char_a = GoodJob::Job.create!(serialized_params: { 'tenant' => tenant, 'user_id' => user.id, 'job_class' => 'ValkyrieCharacterizationJob', 'arguments' => [metadata_a.id.to_s] })
      deriv_b = GoodJob::Job.create!(serialized_params: { 'tenant' => tenant, 'user_id' => user.id, 'job_class' => 'ValkyrieCreateDerivativesJob', 'arguments' => [other_file_set_id, 'file-b'] })

      groups = HykuKnapsack::UserJobs.grouped_for(user)

      expect(groups.map { |group| group[:file_set_id] }).to contain_exactly(file_set_a.id.to_s, other_file_set_id)

      entry_a = groups.find { |group| group[:file_set_id] == file_set_a.id.to_s }
      entry_b = groups.find { |group| group[:file_set_id] == other_file_set_id }
      expect(entry_a[:jobs]).to contain_exactly(deriv_a, char_a)
      expect(entry_b[:jobs]).to contain_exactly(deriv_b)
    end

    it 'excludes jobs whose file set can no longer be resolved' do
      file_set = FactoryBot.valkyrie_create(:hyrax_file_set)
      GoodJob::Job.create!(serialized_params: { 'tenant' => tenant, 'user_id' => user.id, 'job_class' => 'ValkyrieCreateDerivativesJob', 'arguments' => [file_set.id.to_s, 'some-file-id'] })
      GoodJob::Job.create!(serialized_params: { 'tenant' => tenant, 'user_id' => user.id, 'job_class' => 'ValkyrieCharacterizationJob', 'arguments' => ['deleted-file-metadata-id'] })

      groups = HykuKnapsack::UserJobs.grouped_for(user)

      expect(groups.map { |group| group[:file_set_id] }).to contain_exactly(file_set.id.to_s)
    end
  end
end
