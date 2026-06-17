# frozen_string_literal: true

# OVERRIDE IiifPrint v3.0.12 – fix external_latest_file_id for Valkyrie mode and
# route IIIF image requests through an Nginx reverse proxy so UV.js sends cookies.
#
# external_latest_file_id fix:
#   IiifPrint's digest_sha1 expects digest_ssim in "urn:sha1:..." URN format (Wings/Fedora era).
#   In Valkyrie mode, IiifPrint's FileSetIndexerDecorator writes digest_ssim as a plain MD5 hex
#   string (no URN prefix), so digest_sha1 returns nil and the manifest has no canvases.
#   We read digest_ssim directly, strip any URN prefix for Wings compat, and apply the S3 prefix.
#   Remove when: IiifPrint handles plain hex digests in digest_sha1.
#
# Nginx proxy fix (IIIF_PROXY_ENABLED):
#   UV.js uses fetch() with credentials:'same-origin' (the default), so it will not send
#   CloudFront signed cookies to iiif.enacthyku.com because that is a different origin.
#   When IIIF_PROXY_ENABLED is set, manifest URLs are rewritten to point to the same-origin
#   /iiif/ path, which Nginx proxies upstream to CloudFront.  Cookies are forwarded and
#   CloudFront validates them as usual.
#   Remove when: IiifPrint supports IIIF Auth or credentials:'include' is used in UV.
#
# NOTE: Hyrax::IiifManifestPresenter is a class, so mirroring its path would require
# reopening a class as a module — invalid Ruby. The Enact namespace is used instead.
#
# NOTE: The prepend call lives in lib/hyku_knapsack/engine.rb (after_initialize), not here.
module Enact
  module DisplayImagePresenterDecorator
    # OVERRIDE: rewrite the IIIF endpoint URL to use the same-origin proxy path.
    def iiif_endpoint(file_id, base_url: hostname)
      return super unless iiif_proxy_enabled?

      # Hyku sets hostname = request.hostname (no scheme); ensure we have a full HTTPS URL.
      base = base_url.start_with?('http') ? base_url : "https://#{base_url}"
      IIIFManifest::IIIFEndpoint.new(
        "#{base}/iiif/2/#{file_id}",
        profile: Hyrax.config.iiif_image_compliance_level_uri
      )
    end

    # OVERRIDE: build the display image URL via the same-origin proxy path.
    def display_image_url(base_url)
      return super unless iiif_proxy_enabled?

      base = base_url.start_with?('http') ? base_url : "https://#{base_url}"
      proxy_base = "#{base}/iiif/2"
      url_builder = Hyrax.config.iiif_image_url_builder
      args = [latest_file_id, proxy_base, Hyrax.config.iiif_image_size_default]
      args << image_format(alpha_channels) if url_builder.arity == 4
      url_builder.call(*args).gsub(%r{images/}, '')
    end

    private

    def external_latest_file_id
      raw = model['digest_ssim']&.first
      return nil if raw.blank?

      # Return just the hex digest. The Lambda resolver_template handles the S3 prefix.
      raw.sub(/\Aurn:[^:]+:/, '')
    end

    def iiif_proxy_enabled?
      ENV['IIIF_PROXY_ENABLED'].present?
    end
  end
end
