# frozen_string_literal: true

# OVERRIDE iiif_print to build IIIF image/endpoint URLs from the requesting
# tenant's own host instead of the single, static IiifPrint.config.external_iiif_url.
#
# This app is multitenant (Hyku) and each tenant has its own hostname, so a
# single global EXTERNAL_IIIF_URL can't correctly represent "this tenant's
# IIIF host" for every tenant. Hyrax::IiifManifestPresenter::DisplayImagePresenter
# already passes the correct per-request hostname down as `base_url` (see
# Hyrax::DisplaysImage#base_url_for_iiif) -- the upstream gem's methods just
# ignore it in favor of the static config value. We use it instead, and only
# fall back to #base_url_for_iiif (also from Hyrax::DisplaysImage, included via
# our superclass) if a caller doesn't supply one directly.
#
# Note: IiifPrint.config.external_iiif_url must still be set to *some* non-blank
# value for IiifPrint::IiifManifestPresenterFactoryDecorator#for to select
# ExternalIiifDisplayImagePresenter at all -- its actual content is no longer
# used by either method below, only IiifPrint.config.external_iiif_url.present?
# is checked at selection time.
module IiifPrint
  module ExternalIiifDisplayImagePresenterDecorator
    def display_image_url(base_url = nil)
      url_builder = Hyrax.config.iiif_image_url_builder
      args = [latest_file_id, tenant_iiif_base_url(base_url), Hyrax.config.iiif_image_size_default]
      args << image_format(alpha_channels) if url_builder.arity == 4
      url_builder.call(*args).gsub(%r{images/}, '')
    end

    def iiif_endpoint(_file_id = nil, base_url: nil)
      IIIFManifest::IIIFEndpoint.new(
        File.join(tenant_iiif_base_url(base_url), latest_file_id),
        profile: Hyrax.config.iiif_image_compliance_level_uri
      )
    end

    private

    # @param base_url [String, nil] the requesting tenant's own host, as passed
    #   down from Hyrax::IiifManifestPresenter::DisplayImagePresenter#display_image
    #   (falls back to #base_url_for_iiif, from Hyrax::DisplaysImage, when absent
    #   -- e.g. Hyrax::DisplaysContent#thumbnail calls #iiif_endpoint with no
    #   base_url at all). Neither is guaranteed to include a scheme (observed in
    #   practice: `hostname` comes through as a bare host, e.g. `request.host`
    #   rather than `request.base_url`) -- unlike #display_image_url, which goes
    #   through Rails' url_for and gets a scheme added automatically, this method
    #   builds the URL with plain string concatenation, so a missing scheme here
    #   produces a manifest service @id UV can't parse as absolute (it silently
    #   falls back to resolving it relative to its own /uv/ mount instead).
    def tenant_iiif_base_url(base_url)
      host = (base_url || base_url_for_iiif).to_s
      host = "https://#{host}" unless host.match?(%r{\Ahttps?://})
      "#{host}/iiif/2"
    end
  end
end

IiifPrint::ExternalIiifDisplayImagePresenter.prepend(IiifPrint::ExternalIiifDisplayImagePresenterDecorator)
