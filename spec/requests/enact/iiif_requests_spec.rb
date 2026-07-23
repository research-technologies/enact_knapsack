# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Iiifs", type: :request, singletenant: true do
  let(:thumbnail_size) { "!1200,630" }
  let(:current_ability_stub) { instance_double(Ability) }

  before do
    allow(Ability).to receive(:new).and_return(current_ability_stub)
  end

  context 'when the user is allowed to see the image' do
    describe 'GET /show' do
      before do
        allow(current_ability_stub).to receive(:can?).with(:show, "abc-123").and_return(true)
      end
      it 'gives a success message and status' do
        get "/check-iiif", headers: { 'X-Origin-URI' => "/iiif/2/abc-123%2F456-def/full/#{thumbnail_size}/0/default.jpg" }

        expect(response).to have_http_status(:success)
      end
    end
  end
  context 'when the user is not allowed to see the image' do
    before do
      allow(current_ability_stub).to receive(:can?).with(:show, "abc-123").and_return(false)
    end

    it 'gives an unauthorized message and status' do
      get "/check-iiif", headers: { 'X-Origin-URI' => "/iiif/2/abc-123%2F456-def/full/#{thumbnail_size}/0/default.jpg" }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  context 'when the X-Origin-URI is not sent' do
    it 'gives a bad request response' do
      get "/check-iiif"

      expect(response).to have_http_status(:bad_request)
    end
  end
end
