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
    # Keys are values that may appear in `has_model_ssim` on the Solr doc.
    # Includes both the canonical class names (Portfolio / PortfolioItem) and
    # the previous *Resource names so already-indexed records still get a
    # clean label without a reindex.
    ENACT_HUMAN_READABLE_OVERRIDES = {
      'Portfolio' => 'Portfolio',
      'PortfolioItem' => 'Portfolio Item',
      'PortfolioResource' => 'Portfolio',
      'PortfolioItemResource' => 'Portfolio Item'
    }.freeze

    def human_readable_type
      override = ENACT_HUMAN_READABLE_OVERRIDES[Array(solr_document['has_model_ssim']).first]
      override || super
    end

    # For a Portfolio (parent work) `members_include_iiif_viewable?` returns
    # false because the Portfolio's direct members are child *Works*
    # (PortfolioItems), not FileSets - so Hyrax's default check sees no
    # viewable file-set members and skips UV. The Portfolio's IIIF manifest
    # endpoint, however, already enumerates every descendant FileSet as a
    # canvas (via iiif_print's manifest builder), so it's safe to flip UV
    # on when at least one child work exists. For PortfolioItem and every
    # other work type we defer to Hyrax's default check.
    def members_include_iiif_viewable?
      if Array(solr_document['has_model_ssim']).first.in?(%w[Portfolio PortfolioResource])
        Array(solr_document.try(:member_ids) || solr_document.try(:[], 'member_ids_ssim')).any?
      else
        super
      end
    end
  end
end

Hyku::WorkShowPresenter.prepend(Hyku::WorkShowPresenterDecorator)
