# frozen_string_literal: true

# Form for Portfolio. Scalar fields come from the YAML schema via
# Hyrax::FormFields(:portfolio). Compound fields are stored on the model as
# arrays of plain hashes (`type: hash` in the schema) and arrive in form
# params as `<compound>_attributes`. Per-compound virtual properties +
# populators normalize the nested-attributes payload, drop rows marked
# _destroy, and write through to the model. The deserialize! override
# mirrors Hyrax::RedirectsFieldBehavior: strip the auto-renamed `<compound>`
# key so the `_attributes` populator is the only write path.
#
# @see app/forms/concerns/hyrax/redirects_field_behavior.rb in the hyrax gem
# @see https://github.com/samvera/hyrax/wiki/Hyrax-Valkyrie-Usage-Guide#forms
class PortfolioForm < Hyrax::Forms::ResourceForm(Portfolio)
  if Hyrax.config.work_include_metadata?
    include Hyrax::FormFields(:portfolio)
  end
  check_if_flexible(Portfolio)

  COMPOUND_ATTRIBUTES = {
    titles: %w[value title_type lang],
    dates: %w[value date_type date_information],
    contributors: %w[given_name family_name contributor_name name_type role_label role_id role_vocabulary
                     name_identifier scheme_uri affiliation affiliation_identifier],
    identifiers: %w[value identifier_type],
    funding_references: %w[funder_name funder_identifier funder_identifier_type schemeURI award_number award_uri award_title],
    organisational_units: %w[name pid unit_type],
    licenses: %w[rights_label rights_uri rights_identifier rights_identifier_scheme scheme_uri lang holder]
  }.freeze

  # Visual grouping of compound sub-fields in the form. Each row in the form
  # renders as a card with these clusters; `cols` is the Bootstrap column width
  # (1-12) for each input inside the cluster.
  COMPOUND_FIELD_GROUPS = {
    titles: [
      { label: nil, cols: 6, fields: %w[value title_type lang] }
    ],
    dates: [
      { label: nil, cols: 4, fields: %w[value date_type date_information] }
    ],
    contributors: [
      { label: 'Identity', cols: 6, fields: %w[given_name family_name contributor_name name_type] },
      { label: 'Role',     cols: 4, fields: %w[role_label role_id role_vocabulary] },
      { label: 'Identifier', cols: 6, fields: %w[name_identifier scheme_uri] },
      { label: 'Affiliation', cols: 6, fields: %w[affiliation affiliation_identifier] }
    ],
    identifiers: [
      { label: nil, cols: 6, fields: %w[value identifier_type] }
    ],
    funding_references: [
      { label: 'Funder', cols: 6, fields: %w[funder_name funder_identifier funder_identifier_type schemeURI] },
      { label: 'Award',  cols: 4, fields: %w[award_number award_uri award_title] }
    ],
    organisational_units: [
      { label: nil, cols: 4, fields: %w[name pid unit_type] }
    ],
    licenses: [
      { label: 'Statement', cols: 6, fields: %w[rights_label rights_uri holder] },
      { label: 'Identifier', cols: 4, fields: %w[rights_identifier rights_identifier_scheme scheme_uri] },
      { label: 'Language', cols: 4, fields: %w[lang] }
    ]
  }.freeze

  COMPOUND_ATTRIBUTES.each_key do |key|
    property :"#{key}_attributes", virtual: true, populator: :"#{key}_attributes_populator"

    define_method("#{key}_attributes_populator") do |fragment:, **|
      send("#{key}=", build_compound_rows(fragment, key))
    end
  end

  # Permit each compound's nested-attributes hash. Hyrax::Forms::ResourceForm
  # doesn't define a class-level `build_permitted_params`, so guard the super
  # call (matches the pattern used in Hyrax 5.2's WorkForm subclasses elsewhere).
  def self.build_permitted_params
    base = defined?(super) ? super : []
    base + COMPOUND_ATTRIBUTES.map { |key, attrs| { :"#{key}_attributes" => attrs + %w[_destroy] } }
  end

  # Strip the auto-renamed keys so the *_attributes populators own the
  # write path for compounds.
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

PortfolioResourceForm = PortfolioForm unless defined?(PortfolioResourceForm)
