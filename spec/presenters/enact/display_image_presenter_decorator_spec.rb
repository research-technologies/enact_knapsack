# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Enact::DisplayImagePresenterDecorator do
  subject(:presenter) { Hyrax::IiifManifestPresenter::DisplayImagePresenter.new(solr_doc) }
  let(:solr_doc) { SolrDocument.new(id: 'fs-123', **fields) }

  before { allow(ENV).to receive(:[]).and_call_original }

  describe '#external_latest_file_id' do
    context 'when digest_ssim is a plain MD5 hex string (Valkyrie mode)' do
      let(:fields) { { 'digest_ssim' => ['542cd898c5be91687e6c6f2c4f53f2d5'] } }

      context 'without a folder prefix' do
        before { allow(ENV).to receive(:[]).with('IIIF_S3_FOLDER_PREFIX').and_return(nil) }

        it 'returns the MD5 as-is' do
          expect(presenter.send(:external_latest_file_id))
            .to eq('542cd898c5be91687e6c6f2c4f53f2d5')
        end
      end

      context 'with a folder prefix' do
        before { allow(ENV).to receive(:[]).with('IIIF_S3_FOLDER_PREFIX').and_return('staging') }

        it 'percent-encodes the slash so the key is a single IIIF path segment' do
          expect(presenter.send(:external_latest_file_id))
            .to eq('staging%2F542cd898c5be91687e6c6f2c4f53f2d5')
        end
      end
    end

    context 'when digest_ssim is in urn:sha1 format (Wings/Fedora mode)' do
      let(:fields) { { 'digest_ssim' => ['urn:sha1:620cae0e5cf89d9a788cb7d8e31fcbfa78340284'] } }

      before { allow(ENV).to receive(:[]).with('IIIF_S3_FOLDER_PREFIX').and_return(nil) }

      it 'strips the URN prefix and returns the hex digest' do
        expect(presenter.send(:external_latest_file_id))
          .to eq('620cae0e5cf89d9a788cb7d8e31fcbfa78340284')
      end
    end

    context 'when digest_ssim is absent' do
      let(:fields) { {} }

      it 'returns nil' do
        expect(presenter.send(:external_latest_file_id)).to be_nil
      end
    end
  end
end
