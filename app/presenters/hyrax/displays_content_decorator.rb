# frozen_string_literal: true

# OVERRIDE Hyrax v5.2.0 to add https to the thumbnail for audio content and to
# emit an adaptive HLS body for video on works whose per-work viewer supports HLS.

module Hyrax
  module DisplaysContentDecorator
    HLS_VIEWERS = %i[clover ramp].freeze

    def video_content
      return super unless hls_available?

      IIIFManifest::V3::DisplayContent.new(
        hls_url,
        label: 'hls',
        width: Array(width).first.try(:to_i),
        height: Array(height).first.try(:to_i),
        duration: conformed_duration,
        type: 'Video',
        format: Hyrax::HlsDerivativeService::PLAYLIST_CONTENT_TYPE,
        thumbnail:
      )
    end

    def audio_content
      IIIFManifest::V3::DisplayContent.new(
        download_path('mp3'),
        label: 'mp3',
        duration: conformed_duration,
        type: 'Sound',
        # I think UV has a bug where if it's 'audio/mpeg' then it would load, so adding this
        # workaround to use 'audio/mp3' (which isn't even an official MIME type).
        format: viewer == :universal_viewer ? 'audio/mp3' : mime_type,
        thumbnail: [{
          id: "https://#{hostname}#{ActionController::Base.helpers.asset_path('audio.png')}",
          type: 'Image',
          format: 'image/png'
        }]
      )
    end

    private

    def hls_available?
      HLS_VIEWERS.include?(viewer) &&
        File.exist?(Hyrax::HlsDerivativeService.playlist_path_for(object.id))
    end

    def hls_url
      HykuKnapsack::Engine.routes.url_helpers.file_set_hls_url(
        id: object.id, path: Hyrax::HlsDerivativeService::PLAYLIST, host: hostname, protocol: 'https'
      )
    end

    def viewer
      (try(:media_viewer) || Hyrax.config.iiif_av_viewer)&.to_sym
    end

    # OVERRIDE to always return https, consider contributing back to Hyrax
    def download_path(extension)
      Hyrax::Engine.routes.url_helpers.download_url(object, file: extension, host: hostname, protocol: 'https')
    end
  end
end

Hyrax::DisplaysContent.prepend(Hyrax::DisplaysContentDecorator)
