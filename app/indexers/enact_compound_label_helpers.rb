# frozen_string_literal: true

# Builds human-readable Solr-side labels for each PR Voices compound row. The
# show page reads these strings directly via the SolrDocumentDecorator
# attributes (title_label, date_label, contributor_label, etc.), so this
# module is the one place to enrich how a compound row reads to a depositor.
module EnactCompoundLabelHelpers
  # Read `resource.<attr>`, build a label per row via the named helper, write
  # the resulting array to `<key>_tesim` + `<key>_sim` so the show page and
  # facet sidebar see it. Used by PortfolioIndexer / PortfolioItemIndexer.
  def write_compound_labels(doc, attr, key, builder_method)
    labels = compact_labels(Array(resource.send(attr))) { |row| send(builder_method, row) }
    doc["#{key}_tesim"] = labels
    doc["#{key}_sim"]   = labels
  end

  private

  # Iterate rows, coerce each into a Hash, hand to the block, then drop blanks.
  def compact_labels(rows)
    rows.map { |row| yield(coerce_row(row)) }.map(&:presence).compact
  end

  def coerce_row(row)
    return row if row.is_a?(Hash)
    return JSON.parse(row) if row.is_a?(String) && row.start_with?('{')
    {}
  rescue JSON::ParserError
    {}
  end

  # "Avery Brooks (composer) - ORCID 0000-0001-2345-6789, Goldsmiths"
  def contributor_label(row)
    return nil unless row.is_a?(Hash)
    name = row['contributor_name'].presence ||
           [row['given_name'], row['family_name']].compact.reject(&:empty?).join(' ').presence
    return nil unless name

    bits = [name]
    bits << "(#{row['role_label']})" if row['role_label'].present?
    extras = []
    if row['name_identifier'].present?
      scheme = row['name_identifier'].include?('-') ? 'ORCID' : 'ID'
      extras << "#{scheme} #{row['name_identifier']}"
    end
    extras << row['affiliation'] if row['affiliation'].present?
    bits << "- #{extras.join(', ')}" if extras.any?
    bits.join(' ')
  end

  # "Bonfire (working) (AlternativeTitle, en)"
  def title_label(row)
    return nil unless row.is_a?(Hash) && row['value'].present?
    annotation = [row['title_type'], row['lang']].compact_blank
    annotation.any? ? "#{row['value']} (#{annotation.join(', ')})" : row['value']
  end

  # "2024-09-01 (Created) - first sketch"
  def date_label(row)
    return nil unless row.is_a?(Hash) && row['value'].present?
    label = row['value']
    label += " (#{row['date_type']})" if row['date_type'].present?
    label += " - #{row['date_information']}" if row['date_information'].present?
    label
  end

  # "AHRC - Award AH/V003456/1 / Practice Research Cycle"
  def funder_label(row)
    return nil unless row.is_a?(Hash) && row['funder_name'].present?
    award_bits = [row['award_number'].presence && "Award #{row['award_number']}", row['award_title']].compact_blank
    award_bits.any? ? "#{row['funder_name']} - #{award_bits.join(' / ')}" : row['funder_name']
  end

  # "CC BY 4.0 (Avery Brooks)"
  def license_label_for(row)
    return nil unless row.is_a?(Hash) && row['rights_label'].present?
    row['holder'].present? ? "#{row['rights_label']} (#{row['holder']})" : row['rights_label']
  end

  # "School of Music (Department)"
  def organisational_unit_label(row)
    return nil unless row.is_a?(Hash) && row['name'].present?
    row['unit_type'].present? ? "#{row['name']} (#{row['unit_type']})" : row['name']
  end

  # "doi:10.1234/foo (doi)"
  def identifier_value_for(row)
    return nil unless row.is_a?(Hash) && row['value'].present?
    row['identifier_type'].present? ? "#{row['value']} (#{row['identifier_type']})" : row['value']
  end

  # "Tate Modern, London - 51.5076, -0.0994"
  def geo_place_name(row)
    return nil unless row.is_a?(Hash) && row['place_name'].present?
    coords = ("#{row['point_latitude']}, #{row['point_longitude']}" if row['point_latitude'].present? && row['point_longitude'].present?)
    coords ? "#{row['place_name']} - #{coords}" : row['place_name']
  end
end
