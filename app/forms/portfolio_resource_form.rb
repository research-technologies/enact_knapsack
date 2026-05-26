# frozen_string_literal: true

# Form for PortfolioResource. Scalar fields come from the YAML schema via
# Hyrax::FormFields(:portfolio_resource). Compound fields are declared as
# `type: hash` in the schema and arrive here as arrays of hashes; populators
# normalize the nested-attributes form payload, drop rows marked _destroy,
# and persist plain hashes.
#
# @see https://github.com/samvera/hyrax/wiki/Hyrax-Valkyrie-Usage-Guide#forms
# @see app/forms/concerns/hyrax/redirects_field_behavior.rb in the hyrax gem
class PortfolioResourceForm < Hyrax::Forms::ResourceForm(PortfolioResource)
  if Hyrax.config.work_include_metadata?
    include Hyrax::FormFields(:portfolio_resource)
  end
  check_if_flexible(PortfolioResource)

  COMPOUND_ATTRIBUTES = {
    contributors: %i[given_name family_name contributor_name name_type role_label role_id role_vocabulary
                     name_identifier scheme_uri affiliation affiliation_identifier],
    identifiers: %i[value identifier_type],
    funding_references: %i[funder_name funder_identifier funder_identifier_type award_number award_uri award_title],
    organisational_units: %i[name pid unit_type],
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
