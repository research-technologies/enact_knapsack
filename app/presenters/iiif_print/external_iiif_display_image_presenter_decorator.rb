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

    # @param base_url [String, nil] the requesting tenant's own host (with
    #   scheme), as passed down from
    #   Hyrax::IiifManifestPresenter::DisplayImagePresenter#display_image.
    #   Falls back to #base_url_for_iiif (Hyrax::DisplaysImage) when absent,
    #   e.g. when called directly outside the normal manifest-building flow.
    def tenant_iiif_base_url(base_url)
      "#{base_url || base_url_for_iiif}/iiif/2"
    end
  end
end

IiifPrint::ExternalIiifDisplayImagePresenter.prepend(IiifPrint::ExternalIiifDisplayImagePresenterDecorator)
