# frozen_string_literal: true

# OVERRIDE Hyrax v5.2.0 Hyrax::DisplaysTranscripts#transcript_url to force https

module Hyrax
  module TranscriptUrlDecorator
    def transcript_url(document, host: hostname, file_ext: "vtt")
      Hyrax::Engine.routes.url_helpers.transcript_url(document.id, host:, file_ext:, protocol: 'https')
    end
  end
end

Hyrax::IiifManifestPresenter::DisplayImagePresenter.prepend(Hyrax::TranscriptUrlDecorator)
