# frozen_string_literal: true

# Flatten compound hash entries into searchable Solr fields. See
# PortfolioResourceIndexer for the shared pattern; this indexer adds
# `geo_place_name_*` for the Artefact/Event geo_locations compound.
class PortfolioItemResourceIndexer < Hyrax::ValkyrieWorkIndexer
  if Hyrax.config.work_include_metadata?
    include Hyrax::Indexer(:core_metadata)
    include Hyrax::Indexer(:portfolio_item_resource)
  end
  check_if_flexible(PortfolioItemResource)

  def to_solr
    super.tap do |doc|
      contrib_labels = compact_labels(Array(resource.contributors)) { |row| contributor_label(row) }
      doc['contributor_label_tesim'] = contrib_labels
      doc['contributor_label_sim'] = contrib_labels

      funder_labels = compact_labels(Array(resource.funding_references)) { |row| row['funder_name'] }
      doc['funder_label_tesim'] = funder_labels
      doc['funder_label_sim'] = funder_labels

      license_labels = compact_labels(Array(resource.licenses)) { |row| row['rights_label'] }
      doc['license_label_tesim'] = license_labels
      doc['license_label_sim'] = license_labels

      unit_labels = compact_labels(Array(resource.organisational_units)) { |row| row['name'] }
      doc['organisational_unit_label_tesim'] = unit_labels
      doc['organisational_unit_label_sim'] = unit_labels

      ident_values = compact_labels(Array(resource.identifiers)) { |row| row['value'] }
      doc['identifier_value_tesim'] = ident_values
      doc['identifier_value_sim'] = ident_values

      place_names = compact_labels(Array(resource.geo_locations)) { |row| row['place_name'] }
      doc['geo_place_name_tesim'] = place_names
      doc['geo_place_name_sim'] = place_names
    end
  end

  private

  def compact_labels(rows)
    rows.map { |row| row.respond_to?(:[]) ? yield(row) : nil }.map(&:presence).compact
  end

  def contributor_label(row)
    return nil unless row.respond_to?(:[])
    row['contributor_name'].presence ||
      [row['given_name'], row['family_name']].compact.join(' ').presence
  end
end
