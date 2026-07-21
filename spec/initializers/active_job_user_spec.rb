# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ActiveJobUser wiring' do
  let(:user) { FactoryBot.create(:user) }

  after { HykuKnapsack::Current.reset }

  it 'stamps the current user onto any enqueued job' do
    HykuKnapsack::Current.user = user
    job_class = Class.new(ActiveJob::Base) { def perform; end }

    expect(job_class.new.serialize).to include('user_id' => user.id)
  end
end
