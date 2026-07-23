# frozen_string_literal: true

require 'open3'

module Hyrax
  # Generates an adaptive-bitrate HLS ladder for a video file set.
  class HlsDerivativeService
    PLAYLIST = 'index.m3u8'
    PLAYLIST_CONTENT_TYPE = 'application/vnd.apple.mpegurl'
    AUDIO_BITRATE = '128k'
    HIGH_BITRATE = '3000k'
    MEDIUM_BITRATE = '1500k'
    LOW_BITRATE = '500k'
    STANDARD_HEIGHTS = [1080, 720, 480].freeze

    class << self
      # Sibling of the mp4 derivative; shared with HlsController.
      def directory_for(file_set_id)
        base = Hyrax::DerivativePath.derivative_path_for_reference(file_set_id.to_s, 'hls')
        Pathname.new(base.delete_suffix('.hls'))
      end

      def playlist_path_for(file_set_id)
        directory_for(file_set_id).join(PLAYLIST)
      end
    end

    attr_reader :file_set

    def initialize(file_set:)
      @file_set = file_set
    end

    def generate(source_path)
      source_path = source_path.to_s
      return directory if fresh?(source_path) # retry: tree already matches the source

      heights = target_heights
      # ponytail: no per-file-set lock; FileListener enqueues once, so add one only if runs race here.
      FileUtils.rm_rf(directory) # drop a stale/partial tree before rebuilding
      FileUtils.mkdir_p(directory)
      _out, err, status = Open3.capture3(*ffmpeg_command(source_path, heights))
      unless status.success?
        Hyrax.logger.error("HLS generation failed for FileSet #{id}: #{err}")
        FileUtils.rm_rf(directory) # no half-built tree; manifest falls back to mp4
        return
      end
      directory
    end

    # Standard heights below the source, plus one at the source, so we never upscale.
    def target_heights
      h = source_height
      h = 1080 if h <= 0
      source_rung = [h, 1080].min
      source_rung -= 1 if source_rung.odd? # libx264 rejects odd dimensions
      (STANDARD_HEIGHTS.select { |t| t < h } + [source_rung]).uniq.sort.reverse
    end

    private

    # Fresh if the playlist is at least as new as the source: a replaced source
    # rebuilds, a retry skips. Assumes ffmpeg writes the master last (5.1.8).
    def fresh?(source_path)
      playlist = directory.join(PLAYLIST)
      File.exist?(playlist) && File.mtime(playlist) >= File.mtime(source_path)
    end

    def id
      (file_set.try(:file_set_id) || file_set.id).to_s
    end

    def directory
      self.class.directory_for(id)
    end

    def source_height
      Array(file_set.height).first.to_i
    end

    def bitrate_for(height)
      return HIGH_BITRATE if height >= 1080
      return MEDIUM_BITRATE if height >= 720

      LOW_BITRATE
    end

    def ffmpeg_command(source_path, heights)
      audio = audio?(source_path)
      n = heights.size
      splits = (0...n).map { |i| "[v#{i}]" }.join
      scales = heights.each_with_index.map { |h, i| "[v#{i}]scale=-2:#{h}[v#{i}out]" }.join(';')
      cmd = ['ffmpeg', '-y', '-i', source_path, '-filter_complex', "[0:v]split=#{n}#{splits};#{scales}"]
      heights.each_with_index do |h, i|
        cmd += ['-map', "[v#{i}out]", "-c:v:#{i}", 'libx264', "-b:v:#{i}", bitrate_for(h),
                '-preset', 'medium', '-g', '48', '-keyint_min', '48', '-sc_threshold', '0']
      end
      n.times { |i| cmd += ['-map', 'a:0', "-c:a:#{i}", 'aac', "-b:a:#{i}", AUDIO_BITRATE] } if audio
      cmd + packaging_args(n, audio)
    end

    def packaging_args(rungs, audio)
      var_map = (0...rungs).map { |i| audio ? "v:#{i},a:#{i}" : "v:#{i}" }.join(' ')
      # Segmented, not single_file: small .ts cache better behind the CDN.
      ['-f', 'hls', '-hls_playlist_type', 'vod', '-hls_time', '6',
       '-hls_segment_filename', directory.join('v%v_%d.ts').to_s,
       '-master_pl_name', PLAYLIST, '-var_stream_map', var_map,
       directory.join('v%v.m3u8').to_s]
    end

    # Silent sources have no audio stream; an unconditional -map a:0 would fail the ladder.
    def audio?(source_path)
      out, err, status = Open3.capture3('ffprobe', '-v', 'error', '-select_streams', 'a',
                                        '-show_entries', 'stream=index', '-of', 'csv=p=0', source_path)
      Hyrax.logger.warn("ffprobe failed for #{source_path}, treating as no audio: #{err}") unless status.success?
      status.success? && out.strip.present?
    end
  end
end
