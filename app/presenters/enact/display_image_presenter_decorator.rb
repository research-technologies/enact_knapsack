# frozen_string_literal: true

require 'cgi'

# OVERRIDE IiifPrint v3.0.12 – fix external_latest_file_id for Valkyrie mode.
# IiifPrint's digest_sha1 expects digest_ssim in "urn:sha1:..." URN format (Wings/Fedora era).
# In Valkyrie mode, IiifPrint's FileSetIndexerDecorator writes digest_ssim as a plain MD5 hex
# string (no URN prefix), so digest_sha1 returns nil and the manifest has no canvases.
# We read digest_ssim directly, strip any URN prefix for Wings compat, and apply the S3 prefix.
# Remove when: IiifPrint handles plain hex digests in digest_sha1.
module Enact
  module DisplayImagePresenterDecorator
    private

    def external_latest_file_id
      raw = model['digest_ssim']&.first
      return nil if raw.blank?

      hex    = raw.sub(/\Aurn:[^:]+:/, '')
      prefix = ENV['IIIF_S3_FOLDER_PREFIX'].presence
      CGI.escape([prefix, hex].compact.join('/'))
    end
  end
end

Hyrax::IiifManifestPresenter::DisplayImagePresenter
  .prepend(Enact::DisplayImagePresenterDecorator)
