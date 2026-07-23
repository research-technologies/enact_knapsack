# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Hyrax::HlsDerivativeService do
  describe '.directory_for' do
    let(:id) { 'fee426df-702f-47eb-9c96-bb4e6aead789' }

    it 'is a deterministic hls directory under the derivatives path' do
      dir = described_class.directory_for(id)
      expect(dir.to_s).to start_with(Hyrax.config.derivatives_path.to_s)
      expect(dir.to_s).to end_with('-hls')
      expect(described_class.directory_for(id)).to eq(dir)
    end

    it 'places the top-level playlist inside that directory' do
      expect(described_class.playlist_path_for(id).to_s)
        .to eq("#{described_class.directory_for(id)}/index.m3u8")
    end
  end

  # Assert on the HLS tree ffmpeg actually produces from a fixture, not on the
  # command we build. Fixtures are passed as Pathnames (what the real caller
  # passes), which also covers source-path coercion.
  describe '#generate (real ffmpeg on a fixture)' do
    def fixture(name)
      HykuKnapsack::Engine.root.join('spec', 'fixtures', name)
    end

    def stream_count(file, kind)
      out, = Open3.capture3('ffprobe', '-v', 'error', '-select_streams', kind,
                            '-show_entries', 'stream=index', '-of', 'csv=p=0', file.to_s)
      out.strip.lines.count
    end

    def generate_tree(fixture_name, height:, id:)
      described_class.new(file_set: Hyrax::FileMetadata.new(height: [height], file_set_id: id))
                     .generate(fixture(fixture_name))
      described_class.directory_for(id)
    end

    after do
      %w[result-multi result-silent result-audio probe-fail].each { |id| FileUtils.rm_rf(described_class.directory_for(id)) }
    end

    it 'writes a master playlist with one variant per rung' do
      dir = generate_tree('silent_video.mp4', height: 1080, id: 'result-multi')

      expect(File.read(dir.join('index.m3u8')).scan('#EXT-X-STREAM-INF').size).to eq(3)
      expect(Dir.children(dir)).to include('v0.m3u8', 'v1.m3u8', 'v2.m3u8')
    end

    it 'produces playable video with no audio track from a silent source' do
      dir = generate_tree('silent_video.mp4', height: 480, id: 'result-silent')
      segment = Dir.glob(dir.join('v0_*.ts')).first

      expect(stream_count(segment, 'v')).to be >= 1
      expect(stream_count(segment, 'a')).to eq(0)
    end

    it 'carries the audio track into the segments for a source with audio' do
      dir = generate_tree('video_with_audio.mp4', height: 480, id: 'result-audio')
      segment = Dir.glob(dir.join('v0_*.ts')).first

      expect(stream_count(segment, 'a')).to be >= 1
    end

    it 'still encodes video (dropping audio) when ffprobe fails to probe the source' do
      # Fail only the source probe; the real ffmpeg encode and the segment probe below run.
      allow(Open3).to receive(:capture3).and_wrap_original do |original, *args|
        if args.first == 'ffprobe' && args.last.to_s.end_with?('video_with_audio.mp4')
          ['', 'boom', instance_double(Process::Status, success?: false)]
        else
          original.call(*args)
        end
      end

      dir = generate_tree('video_with_audio.mp4', height: 480, id: 'probe-fail')
      segment = Dir.glob(dir.join('v0_*.ts')).first

      expect(File.exist?(described_class.playlist_path_for('probe-fail'))).to be(true)
      expect(stream_count(segment, 'v')).to be >= 1
      expect(stream_count(segment, 'a')).to eq(0)
    end
  end

  describe '#generate freshness (regenerate on replacement, skip on retry)' do
    let(:id) { 'fresh-spec' }
    let(:dir) { described_class.directory_for(id) }
    let(:source) { '/tmp/fresh-source.mp4' }
    let(:service) { described_class.new(file_set: Hyrax::FileMetadata.new(height: [480], file_set_id: id)) }

    before do
      File.write(source, 'x')
      FileUtils.mkdir_p(dir)
      File.write(dir.join('index.m3u8'), '#EXTM3U')
    end

    after do
      FileUtils.rm_rf(dir)
      FileUtils.rm_f(source)
    end

    it 'skips when the existing tree is newer than the source (a retry)' do
      older = File.mtime(dir.join('index.m3u8')) - 100
      File.utime(older, older, source)

      expect(Open3).not_to receive(:capture3)

      service.generate(source)
    end

    it 'regenerates when the source is newer than the tree (a replacement)' do
      newer = File.mtime(dir.join('index.m3u8')) + 100
      File.utime(newer, newer, source)
      allow(Open3).to receive(:capture3).and_return(['', '', instance_double(Process::Status, success?: true)])

      service.generate(source)

      expect(Open3).to have_received(:capture3).at_least(:once)
    end
  end

  describe '#generate when ffmpeg fails' do
    it 'leaves no directory behind' do
      service = described_class.new(file_set: Hyrax::FileMetadata.new(height: [480], file_set_id: 'fail-spec'))
      allow(service).to receive(:audio?).and_return(false)
      allow(Open3).to receive(:capture3).and_return(['', 'boom', instance_double(Process::Status, success?: false)])

      service.generate('/tmp/source.mp4')

      expect(Dir.exist?(described_class.directory_for('fail-spec'))).to be(false)
    end
  end

  describe '#target_heights' do
    def heights_for(source_height)
      described_class.new(file_set: Hyrax::FileMetadata.new(height: [source_height])).target_heights
    end

    it 'emits the full ladder for a 1080p source' do
      expect(heights_for(1080)).to eq([1080, 720, 480])
    end

    it 'drops rungs above the source height' do
      expect(heights_for(720)).to eq([720, 480])
      expect(heights_for(480)).to eq([480])
    end

    it 'never upscales a small source' do
      expect(heights_for(360)).to eq([360])
    end

    it 'keeps a non-standard source height as its own rung' do
      expect(heights_for(500)).to eq([500, 480])
    end

    it 'caps rungs at 1080p for a larger source' do
      expect(heights_for(2160)).to eq([1080, 720, 480])
    end

    it 'snaps an odd source height down to even (libx264 rejects odd dimensions)' do
      expect(heights_for(721)).to eq([720, 480])
      expect(heights_for(501)).to all(be_even)
    end

    it 'falls back to the full ladder when the source height is unknown' do
      expect(described_class.new(file_set: Hyrax::FileMetadata.new).target_heights).to eq([1080, 720, 480])
    end
  end
end
