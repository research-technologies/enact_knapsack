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
      if portfolio?
        Array(solr_document.try(:member_ids) || solr_document.try(:[], 'member_ids_ssim')).any?
      else
        super
      end
    end

    # The `_representative_media.html.erb` partial gates UV on
    # `representative_id.present? && representative_presenter.present?`.
    # Portfolios don't carry a direct FileSet (only their child works do),
    # so Bulkrax / form-driven imports never set `representative_id`. Without
    # this fallback, UV never bootstraps on the Portfolio show page even
    # though the manifest endpoint correctly aggregates every descendant
    # FileSet as a canvas.
    #
    # When the Portfolio has no representative of its own, look up the first
    # member work's representative and present that. Per-presenter memoized
    # so the Solr round-trip happens at most once per request.
    def representative_id
      val = super
      return val if val.present?
      return nil unless portfolio?
      @enact_representative_id ||= first_member_representative_id
    end

    private

    def portfolio?
      Array(solr_document['has_model_ssim']).first.in?(%w[Portfolio PortfolioResource])
    end

    def first_member_representative_id
      member_id = Array(solr_document.try(:member_ids) || solr_document.try(:[], 'member_ids_ssim')).first
      return nil unless member_id
      member_doc = SolrDocument.find(member_id.to_s)
      member_doc&.representative_id
    rescue StandardError => e
      Rails.logger.warn("Enact: failed to resolve first-member representative for #{id}: #{e.class}: #{e.message}")
      nil
    end
  end
end

Hyku::WorkShowPresenter.prepend(Hyku::WorkShowPresenterDecorator)
