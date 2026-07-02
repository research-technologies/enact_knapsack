# frozen_string_literal: true

require 'rails_helper'

# Covers the knapsack override that streams Range responses in chunks.
RSpec.describe Hyrax::DownloadsController, type: :controller do
  routes { Hyrax::Engine.routes }

  let(:user) { FactoryBot.create(:user) }
  let(:file_set) { FactoryBot.valkyrie_create(:hyrax_file_set, edit_users: [user]) }
  let(:content) { IO.binread(Hyrax::Engine.root.join('spec', 'fixtures', 'world.png').to_s) }

  before do
    FactoryBot.valkyrie_create(:hyrax_file_metadata, :with_file, :original_file, :image, file_set:)
    sign_in user
    allow(controller).to receive(:authorize!).and_return(true)
    allow(controller).to receive(:workflow_restriction?).and_return(false)
  end

  describe '#show with a Range header' do
    it 'sends exactly the requested bytes across multiple chunks' do
      stub_const('Hyrax::ValkyrieDownloadsControllerBehaviorDecorator::CHUNK_SIZE', 1024)
      request.env['HTTP_RANGE'] = 'bytes=100-4099'
      get :show, params: { id: file_set.id.to_s }
      expect(response.status).to eq 206
      expect(response.headers['Content-Range']).to eq "bytes 100-4099/#{content.bytesize}"
      expect(response.headers['Content-Length']).to eq '4000'
      expect(response.body.b).to eq content.byteslice(100, 4000)
    end

    it 'sends the rest of the file for an open ended range' do
      request.env['HTTP_RANGE'] = 'bytes=100-'
      get :show, params: { id: file_set.id.to_s }
      expect(response.status).to eq 206
      expect(response.body.b).to eq content.byteslice(100, content.bytesize - 100)
    end
  end
end
