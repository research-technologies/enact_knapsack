# frozen_string_literal: true

# Flatten compound hash entries into searchable Solr fields. See
# PortfolioIndexer for the shared pattern; this indexer adds `geo_place_name_*`
# for the Artefact/Event geo_locations compound.
class PortfolioItemIndexer < Hyrax::ValkyrieWorkIndexer
  include EnactCompoundLabelHelpers
  include HykuIndexing

  if Hyrax.config.work_include_metadata?
    include Hyrax::Indexer(:core_metadata)
    include Hyrax::Indexer(:portfolio_item)
  end
  check_if_flexible(PortfolioItem)

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

      place_names = compact_labels(Array(resource.geo_locations)) { |row| geo_place_name(row) }
      doc['geo_place_name_tesim'] = place_names
      doc['geo_place_name_sim']   = place_names
    end
  end
end

PortfolioItemResourceIndexer = PortfolioItemIndexer unless defined?(PortfolioItemResourceIndexer)
