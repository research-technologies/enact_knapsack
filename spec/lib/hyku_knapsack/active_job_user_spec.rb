# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HykuKnapsack::ActiveJobUser do
  let(:user) { FactoryBot.create(:user) }
  let(:performed_as) { [] }

  after { HykuKnapsack::Current.reset }

  before do
    captured = performed_as
    stub_const('SpecUserJob', Class.new(ActiveJob::Base) do
      include HykuKnapsack::ActiveJobUser
      define_method(:perform) { captured << HykuKnapsack::Current.user&.id }
    end)
  end

  it 'serializes the current user id onto the job' do
    HykuKnapsack::Current.user = user

    expect(SpecUserJob.new.serialize).to include('user_id' => user.id)
  end

  it 'restores the user id from serialized job data' do
    HykuKnapsack::Current.user = user
    data = SpecUserJob.new.serialize

    expect(SpecUserJob.deserialize(data).user_id).to eq(user.id)
  end

  it 'restores the current user while the job runs, so enqueued children inherit it' do
    HykuKnapsack::Current.user = user
    data = SpecUserJob.new.serialize
    HykuKnapsack::Current.user = nil

    SpecUserJob.deserialize(data).perform_now

    expect(performed_as).to eq([user.id])
  end

  it 'runs a job with no user without raising, and does not inherit a stale user' do
    HykuKnapsack::Current.user = user

    SpecUserJob.new.perform_now

    expect(performed_as).to eq([nil])
  end

  it 'restores the previous current user after performing inline' do
    HykuKnapsack::Current.user = user

    SpecUserJob.new.perform_now

    expect(HykuKnapsack::Current.user).to eq(user)
  end
end
