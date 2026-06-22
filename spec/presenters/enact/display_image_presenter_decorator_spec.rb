# frozen_string_literal: true

require 'rails_helper'

# Test the module's behaviour directly via a minimal host class so the spec is
# independent of the presenter load order (which engine/gem prepends last in CI).
RSpec.describe Enact::DisplayImagePresenterDecorator do
  let(:host_class) do
    Class.new do
      prepend Enact::DisplayImagePresenterDecorator

      def initialize(data)
        @data = data
      end

      def model
        @data
      end

      # Mirrors Hyrax::IiifManifestPresenter::DisplayImagePresenter — hostname is written
      # by the parent presenter; the default matches what IiifPrint ships with.
      def hostname
        @hostname || 'localhost'
      end

      attr_writer :hostname

      def latest_file_id
        model['digest_ssim']&.first&.sub(/\Aurn:[^:]+:/, '')
      end

      def alpha_channels
        nil
      end

      def image_format(_channels)
        'image/jpeg'
      end
    end
  end

  subject(:presenter) { host_class.new(solr_doc) }
  let(:solr_doc) { { 'digest_ssim' => digest_values } }

  before { allow(ENV).to receive(:[]).and_call_original }

  describe '#external_latest_file_id' do
    context 'when iiif_file_identifier_ss is present in the Solr document' do
      let(:solr_doc) { { 'iiif_file_identifier_ss' => 'uuid-part-1/uuid-part-2' } }

      it 'returns the S3 key with / encoded as %2F' do
        expect(presenter.send(:external_latest_file_id)).to eq('uuid-part-1%2Fuuid-part-2')
      end
    end

    context 'when iiif_file_identifier_ss is absent (disk-stored or not yet reindexed)' do
      let(:solr_doc) { {} }

      it 'returns nil' do
        expect(presenter.send(:external_latest_file_id)).to be_nil
      end
    end
  end

  describe '#iiif_endpoint' do
    let(:digest_values) { ['abc123def456'] }
    let(:host) { 'https://demo.enact-knapsack-staging.enacthyku.com' }

    before { presenter.hostname = host }

    context 'when IIIF_PROXY_ENABLED is set' do
      before { allow(ENV).to receive(:[]).with('IIIF_PROXY_ENABLED').and_return('true') }

      it 'returns an endpoint rooted at the same-origin /iiif/2/ path' do
        endpoint = presenter.iiif_endpoint('abc123def456', base_url: host)
        expect(endpoint.url).to eq("#{host}/iiif/2/abc123def456")
      end

      it 'prepends https:// when Hyku passes a bare hostname without scheme' do
        # Hyku overrides Hyrax and sets hostname = request.hostname (no scheme)
        endpoint = presenter.iiif_endpoint('abc123def456', base_url: 'demo.enact-knapsack-staging.enacthyku.com')
        expect(endpoint.url).to eq('https://demo.enact-knapsack-staging.enacthyku.com/iiif/2/abc123def456')
      end
    end

    context 'when IIIF_PROXY_ENABLED is not set' do
      before { allow(ENV).to receive(:[]).with('IIIF_PROXY_ENABLED').and_return(nil) }

      it 'falls through to super' do
        expect { presenter.iiif_endpoint('abc123def456', base_url: host) }.to raise_error(NoMethodError)
      end
    end
  end

  describe '#display_image_url' do
    let(:digest_values) { ['abc123def456'] }
    let(:url_builder) do
      lambda do |file_id, base_url, _size, _format|
        "#{base_url}/images/#{file_id}/full/full/0/default.jpg"
      end
    end

    before do
      allow(Hyrax.config).to receive(:iiif_image_url_builder).and_return(url_builder)
      allow(Hyrax.config).to receive(:iiif_image_size_default).and_return('full')
    end

    context 'when IIIF_PROXY_ENABLED is set' do
      before { allow(ENV).to receive(:[]).with('IIIF_PROXY_ENABLED').and_return('true') }

      it 'builds the image URL using the same-origin /iiif/2 base' do
        result = presenter.display_image_url('https://demo.enact-knapsack-staging.enacthyku.com')
        expect(result).to eq(
          'https://demo.enact-knapsack-staging.enacthyku.com/iiif/2/abc123def456/full/full/0/default.jpg'
        )
      end
    end

    context 'when IIIF_PROXY_ENABLED is not set' do
      before { allow(ENV).to receive(:[]).with('IIIF_PROXY_ENABLED').and_return(nil) }

      it 'falls through to super' do
        expect { presenter.display_image_url('https://demo.enact-knapsack-staging.enacthyku.com') }.to raise_error(NoMethodError)
      end
    end
  end
end
