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

  def to_solr
    super.tap do |doc|
      title_labels = compact_labels(Array(resource.titles)) { |row| title_label(row) }
      doc['title_label_tesim'] = title_labels
      doc['title_label_sim']   = title_labels

      date_labels = compact_labels(Array(resource.dates)) { |row| date_label(row) }
      doc['date_label_tesim'] = date_labels
      doc['date_label_sim']   = date_labels

      contrib_labels = compact_labels(Array(resource.contributors)) { |row| contributor_label(row) }
      doc['contributor_label_tesim'] = contrib_labels
      doc['contributor_label_sim']   = contrib_labels

      funder_labels = compact_labels(Array(resource.funding_references)) { |row| funder_label(row) }
      doc['funder_label_tesim'] = funder_labels
      doc['funder_label_sim']   = funder_labels

      license_labels = compact_labels(Array(resource.licenses)) { |row| license_label_for(row) }
      doc['license_label_tesim'] = license_labels
      doc['license_label_sim']   = license_labels

      unit_labels = compact_labels(Array(resource.organisational_units)) { |row| organisational_unit_label(row) }
      doc['organisational_unit_label_tesim'] = unit_labels
      doc['organisational_unit_label_sim']   = unit_labels

      ident_values = compact_labels(Array(resource.identifiers)) { |row| identifier_value_for(row) }
      doc['identifier_value_tesim'] = ident_values
      doc['identifier_value_sim']   = ident_values
    end
  end
end

PortfolioResourceIndexer = PortfolioIndexer unless defined?(PortfolioResourceIndexer)
