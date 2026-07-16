# frozen_string_literal: true

require 'rails_helper'

# HLS generation fires only for video when ffmpeg and the :hls_streaming feature
# are both on; it always runs the normal derivatives (super) first.
RSpec.describe Hyrax::FileSetDerivativesServiceHlsDecorator do
  subject(:service) { host_class.new(file_set: :fs, mime_type:) }

  let(:mime_type) { 'video/mp4' }
  let(:host_class) do
    Class.new do
      prepend Hyrax::FileSetDerivativesServiceHlsDecorator
      attr_reader :file_set, :mime_type

      def initialize(file_set:, mime_type:)
        @file_set = file_set
        @mime_type = mime_type
      end

      def create_derivatives(_filename); end # stands in for the real derivative chain (super)
    end
  end

  before { allow(Hyrax.config).to receive(:enable_ffmpeg).and_return(true) }

  context 'when the file is video and the feature is on' do
    before { allow(Flipflop).to receive(:enabled?).with(:hls_streaming).and_return(true) }

    it 'generates the HLS ladder' do
      expect(Hyrax::HlsDerivativeService).to receive(:new)
        .with(file_set: :fs).and_return(instance_double(Hyrax::HlsDerivativeService, generate: true))

      service.create_derivatives('/tmp/x.mp4')
    end
  end

  context 'when the feature is off' do
    before { allow(Flipflop).to receive(:enabled?).with(:hls_streaming).and_return(false) }

    it 'does not generate HLS' do
      expect(Hyrax::HlsDerivativeService).not_to receive(:new)

      service.create_derivatives('/tmp/x.mp4')
    end
  end

  context 'when the file is not video' do
    let(:mime_type) { 'image/png' }

    before { allow(Flipflop).to receive(:enabled?).with(:hls_streaming).and_return(true) }

    it 'does not generate HLS' do
      expect(Hyrax::HlsDerivativeService).not_to receive(:new)

      service.create_derivatives('/tmp/x.png')
    end
  end

  context 'when ffmpeg is disabled' do
    before do
      allow(Hyrax.config).to receive(:enable_ffmpeg).and_return(false)
      allow(Flipflop).to receive(:enabled?).with(:hls_streaming).and_return(true)
    end

    it 'does not generate HLS' do
      expect(Hyrax::HlsDerivativeService).not_to receive(:new)

      service.create_derivatives('/tmp/x.mp4')
    end
  end
end
