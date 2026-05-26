# frozen_string_literal: true

# Form for PortfolioItemResource. Same compound-as-hash pattern as
# PortfolioResourceForm, plus a `geo_locations` compound for Artefact/Event
# items.
#
# @see app/forms/portfolio_resource_form.rb
class PortfolioItemResourceForm < Hyrax::Forms::ResourceForm(PortfolioItemResource)
  if Hyrax.config.work_include_metadata?
    include Hyrax::FormFields(:portfolio_item_resource)
  end
  check_if_flexible(PortfolioItemResource)

  COMPOUND_ATTRIBUTES = {
    contributors: %w[given_name family_name contributor_name name_type role_label role_id role_vocabulary
                     name_identifier scheme_uri affiliation affiliation_identifier],
    identifiers: %w[value identifier_type],
    funding_references: %w[funder_name funder_identifier funder_identifier_type award_number award_uri award_title],
    organisational_units: %w[name pid unit_type],
    geo_locations: %w[place_name point_latitude point_longitude west_bound east_bound south_bound north_bound],
    licenses: %w[rights_label rights_uri rights_identifier rights_identifier_scheme scheme_uri lang holder]
  }.freeze

  COMPOUND_ATTRIBUTES.each_key do |key|
    property :"#{key}_attributes", virtual: true, populator: :"#{key}_attributes_populator"

    define_method("#{key}_attributes_populator") do |fragment:, **|
      send("#{key}=", build_compound_rows(fragment, key))
    end
  end

  def self.build_permitted_params
    super + COMPOUND_ATTRIBUTES.map { |key, attrs| { :"#{key}_attributes" => attrs + %w[_destroy] } }
  end

  def deserialize!(params)
    result = super
    return result unless result.respond_to?(:delete)
    COMPOUND_ATTRIBUTES.each_key do |key|
      result.delete(key.to_s)
      result.delete(key)
    end
    result
  end

  private

  def build_compound_rows(fragment, key)
    pairs = compound_fragment_pairs(fragment)
    allowed_keys = COMPOUND_ATTRIBUTES.fetch(key)
    pairs
      .sort_by { |k, _row| k.to_s == '_marker' ? Float::INFINITY : k.to_i }
      .map { |_k, row| compound_row_from(row, allowed_keys) }
      .compact
  end

  def compound_fragment_pairs(fragment)
    return {} if fragment.nil?
    fragment.respond_to?(:to_unsafe_h) ? fragment.to_unsafe_h : fragment.to_h
  end

  def compound_row_from(row, allowed_keys)
    row = row.respond_to?(:to_unsafe_h) ? row.to_unsafe_h : row
    return nil unless row.is_a?(Hash)
    return nil if row['_destroy'].to_s == 'true'
    cleaned = row.slice(*allowed_keys).reject { |_, v| v.to_s.strip.empty? }
    cleaned.empty? ? nil : cleaned
  end
end
