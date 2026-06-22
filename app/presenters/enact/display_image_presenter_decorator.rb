# frozen_string_literal: true

# OVERRIDE IiifPrint v3.0.12 – fix external_latest_file_id for Valkyrie mode and
# route IIIF image requests through an Nginx reverse proxy so UV.js sends cookies.
#
# external_latest_file_id fix:
#   The serverless-iiif Lambda reads images from the Valkyrie repository S3 bucket using the
#   Shrine storage key as the IIIF identifier.  Shrine stores files under "uuid1/uuid2" paths;
#   the "/" must be percent-encoded as "%2F" in the IIIF identifier segment so it isn't parsed
#   as an IIIF path delimiter.  The Lambda decodes "%2F" back to "/" before the S3 key lookup.
#   We look up the Shrine key via Valkyrie's custom query rather than reading digest_ssim.
#   Remove when: IiifPrint has a first-class hook for the IIIF identifier.
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
      key = model['iiif_file_identifier_ss']
      return nil if key.blank?

      key.gsub('/', '%2F')
    end

    def iiif_proxy_enabled?
      ENV['IIIF_PROXY_ENABLED'].present?
    end
  end
end
