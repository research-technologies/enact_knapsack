# frozen_string_literal: true

# Flatten compound hash entries into searchable Solr fields. The schema loader
# already emits `*_label_tesim` / `*_label_sim` index keys (declared on each
# compound in config/metadata/portfolio.yaml); this indexer fills them in by
# reading the persisted hash entries.
#
# Label strings live in EnactCompoundLabelHelpers (shared with
# PortfolioItemIndexer).
class PortfolioIndexer < Hyrax::ValkyrieWorkIndexer
  include EnactCompoundLabelHelpers
  # HykuIndexing supplies the Hyku-specific Solr fields the rest of the app
  # expects: valkyrie_bsi (so SolrDocument#valkyrie? is true, which routes
  # member_ids through the fast Valkyrie path), member_ids_ssim,
  # generic_type_sim, all_text_tsimv, etc. Mirrors the include the Hyku
  # work_resource generator adds.
  include HykuIndexing

  if Hyrax.config.work_include_metadata?
    include Hyrax::Indexer(:core_metadata)
    include Hyrax::Indexer(:portfolio)
  end
  check_if_flexible(Portfolio)

  # `attribute => [solr_field_prefix, label_helper_method]`
  COMPOUND_INDEX_MAP = {
    titles: %i[title_label title_label],
    dates: %i[date_label date_label],
    contributors: %i[contributor_label contributor_label],
    funding_references: %i[funder_label funder_label],
    licenses: %i[license_label license_label_for],
    organisational_units: %i[organisational_unit_label organisational_unit_label],
    identifiers: %i[identifier_value identifier_value_for]
  }.freeze

  def to_solr
    super.tap do |doc|
      COMPOUND_INDEX_MAP.each { |attr, (key, method)| write_compound_labels(doc, attr, key, method) }
    end
  end
end

PortfolioResourceIndexer = PortfolioIndexer unless defined?(PortfolioResourceIndexer)
