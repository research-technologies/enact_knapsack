# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationController, type: :controller do
  controller do
    def index
      render plain: HykuKnapsack::Current.user&.id
    end
  end

  let(:user) { FactoryBot.create(:user) }

  before { sign_in user }

  it 'sets the current user for the duration of the request' do
    get :index

    expect(response.body).to eq(user.id.to_s)
  end
end
