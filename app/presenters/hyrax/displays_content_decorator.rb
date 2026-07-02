# frozen_string_literal: true

# OVERRIDE Hyrax v5.2.0 to add https to the thumbnail for audio content.

module Hyrax
  module DisplaysContentDecorator
    def audio_content
      IIIFManifest::V3::DisplayContent.new(
        download_path('mp3'),
        label: 'mp3',
        duration: conformed_duration,
        type: 'Sound',
        # I think UV has a bug where if it's 'audio/mpeg' then it would load, so adding this
        # workaround to use 'audio/mp3' (which isn't even an official MIME type).
        format: Hyrax.config.iiif_av_viewer == :universal_viewer ? 'audio/mp3' : mime_type,
        thumbnail: [{
          id: "https://#{hostname}#{ActionController::Base.helpers.asset_path('audio.png')}",
          type: 'Image',
          format: 'image/png'
        }]
      )
    end

    private

    # OVERRIDE to always return https, consider contributing back to Hyrax
    def download_path(extension)
      Hyrax::Engine.routes.url_helpers.download_url(object, file: extension, host: hostname, protocol: 'https')
    end
  end
end

Hyrax::DisplaysContent.prepend(Hyrax::DisplaysContentDecorator)
