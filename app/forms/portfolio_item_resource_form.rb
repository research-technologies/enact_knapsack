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
    contributors: %i[given_name family_name contributor_name name_type role_label role_id role_vocabulary
                     name_identifier scheme_uri affiliation affiliation_identifier],
    identifiers: %i[value identifier_type],
    funding_references: %i[funder_name funder_identifier funder_identifier_type award_number award_uri award_title],
    organisational_units: %i[name pid unit_type],
    geo_locations: %i[place_name point_latitude point_longitude west_bound east_bound south_bound north_bound],
    licenses: %i[rights_label rights_uri rights_identifier rights_identifier_scheme scheme_uri lang holder]
  }.freeze

  COMPOUND_ATTRIBUTES.each_key do |key|
    property key, default: [], populator: :"populate_#{key}"

    define_method("populate_#{key}") do |fragment:, **|
      send("#{key}=", build_compound_rows(fragment, key))
    end
  end

  def self.build_permitted_params
    super + COMPOUND_ATTRIBUTES.map { |key, attrs| { key => attrs + %i[_destroy] } }
  end

  private

  def build_compound_rows(fragment, key)
    rows = fragment.is_a?(Hash) ? fragment.values : Array(fragment)
    allowed_keys = COMPOUND_ATTRIBUTES.fetch(key).map(&:to_s)
    rows
      .reject { |row| row.is_a?(Hash) && row['_destroy'].present? }
      .map { |row| row.is_a?(Hash) ? row.slice(*allowed_keys).reject { |_, v| v.blank? } : row }
      .reject(&:blank?)
  end
end
