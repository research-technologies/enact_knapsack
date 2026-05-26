# frozen_string_literal: true

# Override the show-page work-type label for Enact resources so the cube-icon
# row, breadcrumbs, page title, and "no files" message all show "Portfolio"
# / "Portfolio item" instead of "Portfolio Resource" / "Portfolio Item
# Resource".
#
# Hyrax stores `human_readable_type_tesim` to Solr at index time, computed from
# the resource's class-level value (which resolves through I18n at index time).
# Updating the locale alone doesn't change already-indexed records. Intercepting
# on the presenter is safe for both old and new records.
module Hyku
  module WorkShowPresenterDecorator
    ENACT_HUMAN_READABLE_OVERRIDES = {
      'PortfolioResource' => 'Portfolio',
      'PortfolioItemResource' => 'Portfolio Item'
    }.freeze

    def human_readable_type
      override = ENACT_HUMAN_READABLE_OVERRIDES[Array(solr_document['has_model_ssim']).first]
      override || super
    end
  end
end

Hyku::WorkShowPresenter.prepend(Hyku::WorkShowPresenterDecorator)
