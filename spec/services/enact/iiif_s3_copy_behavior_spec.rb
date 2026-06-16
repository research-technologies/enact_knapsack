# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Enact::IiifS3CopyBehavior do
  let(:dummy_class) do
    Class.new do
      def create_derivatives(filename)
        # base implementation — intentionally a no-op
      end
    end.tap { |c| c.prepend(Enact::IiifS3CopyBehavior) } # rubocop:disable Style/MultilineBlockChain
  end

  let(:instance)      { dummy_class.new }
  let(:test_file) do
    Tempfile.new(['iiif_test', '.jpg']).tap do |f|
      f.write('fake image data')
      f.flush
    end
  end
  let(:filename)      { test_file.path }
  let(:sha1)          { Digest::SHA1.file(filename).hexdigest }
  let(:fake_manager)  { instance_double(Aws::S3::TransferManager, upload_file: true) }

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:fetch).and_call_original
    allow(Aws::S3::TransferManager).to receive(:new).and_return(fake_manager)
  end

  after { test_file.unlink }

  # ---------------------------------------------------------------------------
  # Class methods
  # ---------------------------------------------------------------------------

  describe '.bucket_name' do
    it 'returns the IIIF_S3_BUCKET env var' do
      allow(ENV).to receive(:fetch).with('IIIF_S3_BUCKET', 'enact-iiif-images').and_return('my-bucket')
      expect(described_class.bucket_name).to eq('my-bucket')
    end

    it 'defaults to enact-iiif-images' do
      allow(ENV).to receive(:fetch).with('IIIF_S3_BUCKET', 'enact-iiif-images').and_call_original
      expect(described_class.bucket_name).to eq('enact-iiif-images')
    end
  end

  describe '.configured?' do
    context 'when EXTERNAL_IIIF_URL is set' do
      before { allow(ENV).to receive(:[]).with('EXTERNAL_IIIF_URL').and_return('https://iiif.example.com/iiif/2') }

      it { expect(described_class.configured?).to be true }
    end

    context 'when EXTERNAL_IIIF_URL is absent' do
      before { allow(ENV).to receive(:[]).with('EXTERNAL_IIIF_URL').and_return(nil) }

      it { expect(described_class.configured?).to be false }
    end
  end

  describe '.key_for' do
    context 'without a folder prefix' do
      before { allow(ENV).to receive(:[]).with('IIIF_S3_FOLDER_PREFIX').and_return(nil) }

      it 'returns the SHA1 of the file' do
        expect(described_class.key_for(filename)).to eq(sha1)
      end
    end

    context 'with a folder prefix' do
      before { allow(ENV).to receive(:[]).with('IIIF_S3_FOLDER_PREFIX').and_return('staging') }

      it 'prepends the prefix to the SHA1' do
        expect(described_class.key_for(filename)).to eq("staging/#{sha1}")
      end
    end

    it 'raises Errno::ENOENT for a missing file' do
      expect { described_class.key_for('/nonexistent/file.jpg') }.to raise_error(Errno::ENOENT)
    end
  end

  describe '.upload' do
    before do
      allow(ENV).to receive(:[]).with('EXTERNAL_IIIF_URL').and_return('https://iiif.example.com/iiif/2')
      allow(ENV).to receive(:[]).with('IIIF_S3_FOLDER_PREFIX').and_return('staging')
      allow(ENV).to receive(:fetch).with('IIIF_S3_BUCKET', 'enact-iiif-images').and_return('enact-iiif-images')
    end

    it 'uploads the file to the correct S3 bucket and key' do
      described_class.upload(filename)
      expect(fake_manager).to have_received(:upload_file).with(
        bucket: 'enact-iiif-images',
        key: "staging/#{sha1}",
        path: filename
      )
    end

    it 'logs the upload' do
      allow(Rails.logger).to receive(:info)
      described_class.upload(filename)
      expect(Rails.logger).to have_received(:info).with(/uploaded.*s3:\/\/enact-iiif-images\/staging\/#{sha1}/)
    end

    context 'when not configured' do
      before { allow(ENV).to receive(:[]).with('EXTERNAL_IIIF_URL').and_return(nil) }

      it 'does not upload' do
        described_class.upload(filename)
        expect(fake_manager).not_to have_received(:upload_file)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Prepended instance method
  # ---------------------------------------------------------------------------

  describe '#create_derivatives' do
    before do
      allow(ENV).to receive(:[]).with('EXTERNAL_IIIF_URL').and_return('https://iiif.example.com/iiif/2')
      allow(ENV).to receive(:[]).with('IIIF_S3_FOLDER_PREFIX').and_return(nil)
      allow(ENV).to receive(:fetch).with('IIIF_S3_BUCKET', 'enact-iiif-images').and_return('enact-iiif-images')
    end

    it 'calls super' do
      expect(instance).to receive(:create_derivatives).and_call_original
      instance.create_derivatives(filename)
    end

    it 'uploads the file to S3' do
      instance.create_derivatives(filename)
      expect(fake_manager).to have_received(:upload_file).with(
        bucket: 'enact-iiif-images',
        key: sha1,
        path: filename
      )
    end

    context 'when an S3 error occurs' do
      before do
        allow(fake_manager).to receive(:upload_file).and_raise(
          Aws::S3::Errors::ServiceError.new(nil, 'Access Denied')
        )
      end

      it 'logs the error and does not re-raise' do
        allow(Rails.logger).to receive(:error)
        expect { instance.create_derivatives(filename) }.not_to raise_error
        expect(Rails.logger).to have_received(:error).with(/failed to copy to IIIF bucket/)
      end
    end

    context 'when the file is missing' do
      it 'logs the error and does not re-raise' do
        allow(Rails.logger).to receive(:error)
        expect { instance.create_derivatives('/nonexistent/file.jpg') }.not_to raise_error
        expect(Rails.logger).to have_received(:error).with(/failed to copy to IIIF bucket/)
      end
    end

    context 'when not configured' do
      before { allow(ENV).to receive(:[]).with('EXTERNAL_IIIF_URL').and_return(nil) }

      it 'does not upload' do
        instance.create_derivatives(filename)
        expect(fake_manager).not_to have_received(:upload_file)
      end
    end
  end
end
