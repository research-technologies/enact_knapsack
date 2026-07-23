# frozen_string_literal: true

require 'rails_helper'

# The per-work video branch: a Clover work with an HLS tree gets an HLS body;
# UV works and works without a tree fall back to the progressive mp4.
RSpec.describe Hyrax::DisplaysContentDecorator do
  subject(:presenter) { host_class.new(Struct.new(:id).new(file_set_id)) }

  let(:file_set_id) { 'spec-hls-0001' }
  let(:hls_dir) { Hyrax::HlsDerivativeService.directory_for(file_set_id) }

  # Minimal object that mixes in DisplaysContent (with the decorator prepended)
  # and supplies just what video_content / its mp4 super need.
  let(:host_class) do
    Class.new do
      include Hyrax::DisplaysContent
      attr_accessor :media_viewer
      attr_reader :object

      def initialize(object)
        @object = object
      end

      def hostname = 'example.com'
      def width = [1920]
      def height = [1080]
      def mime_type = 'video/mp4'
      def conformed_duration = nil
      def thumbnail = []
      def download_path(_extension) = 'file:///tmp/progressive.mp4'
    end
  end

  after { FileUtils.rm_rf(hls_dir) }

  def build_tree
    FileUtils.mkdir_p(hls_dir)
    File.write(hls_dir.join(Hyrax::HlsDerivativeService::PLAYLIST), "#EXTM3U\n")
  end

  context 'when the work uses Clover and an HLS tree exists' do
    before do
      build_tree
      presenter.media_viewer = :clover
    end

    it 'emits an HLS body pointing at the master playlist' do
      content = presenter.video_content

      expect(content.format).to eq('application/vnd.apple.mpegurl')
      expect(content.url).to end_with("/file_sets/#{file_set_id}/hls/index.m3u8")
    end
  end

  context 'when the work uses Ramp and an HLS tree exists' do
    before do
      build_tree
      presenter.media_viewer = :ramp
    end

    it 'emits an HLS body' do
      expect(presenter.video_content.format).to eq('application/vnd.apple.mpegurl')
    end
  end

  context 'when the work uses Universal Viewer' do
    before do
      build_tree
      presenter.media_viewer = :universal_viewer
    end

    it 'falls back to the progressive mp4' do
      content = presenter.video_content

      expect(content.format).to eq('video/mp4')
    end
  end

  context 'when the work uses Clover but no HLS tree exists' do
    before { presenter.media_viewer = :clover }

    it 'falls back to the progressive mp4' do
      content = presenter.video_content

      expect(content.format).to eq('video/mp4')
    end
  end
end
