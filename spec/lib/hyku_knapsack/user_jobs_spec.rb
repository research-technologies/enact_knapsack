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
end
