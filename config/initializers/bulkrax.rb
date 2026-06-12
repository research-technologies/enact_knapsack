# frozen_string_literal: true

# Adds the Enact compound field mappings to Hyku's default Bulkrax mappings.
#
# Each mapping wires a CSV column family into one member of a `type: hash`
# compound from config/metadata_profiles/m3_profile.yaml: `from:` is the CSV
# column (numbered per entry: contributor_name_1, contributor_name_2, ...),
# `object:` is the compound attribute on the work, and `name:` is the member's
# key inside each entry (the M3 member's `name:`). The mapping's own hash key
# only has to be unique across the whole mapping table, so we use the CSV
# column name throughout.
#
# Assigning Hyku.default_bulkrax_field_mappings here (the engine loads knapsack
# initializers right after the host app's) means new Accounts copy these
# mappings at creation and existing Accounts without a per-tenant override fall
# back to them (see hyrax-webapp lib/bulkrax/per_tenant_field_mapping_decorator.rb).
# Tenants that HAVE saved a per-tenant bulkrax_field_mappings setting keep it
# and need that JSON updated separately.

compound_mappings = {
  # titles - repeatable typed titles
  'title_value' => { from: ['title_value'], object: 'titles', nested_attributes: true, name: 'value' },
  'title_type' => { from: ['title_type'], object: 'titles', nested_attributes: true, name: 'type' },
  'title_lang' => { from: ['title_lang'], object: 'titles', nested_attributes: true, name: 'lang' },
  # dates - typed dates
  'date_value' => { from: ['date_value'], object: 'dates', nested_attributes: true, name: 'value' },
  'date_type' => { from: ['date_type'], object: 'dates', nested_attributes: true, name: 'type' },
  'date_information' => { from: ['date_information'], object: 'dates', nested_attributes: true, name: 'information' },
  # contributors - people/orgs with typed roles (no creator field on Enact)
  'contributor_given_name' => { from: ['contributor_given_name'], object: 'contributors', nested_attributes: true, name: 'given_name' },
  'contributor_family_name' => { from: ['contributor_family_name'], object: 'contributors', nested_attributes: true, name: 'family_name' },
  'contributor_name' => { from: ['contributor_name'], object: 'contributors', nested_attributes: true, name: 'name' },
  'contributor_name_type' => { from: ['contributor_name_type'], object: 'contributors', nested_attributes: true, name: 'name_type' },
  'contributor_role_label' => { from: ['contributor_role_label'], object: 'contributors', nested_attributes: true, name: 'role_label' },
  'contributor_role_id' => { from: ['contributor_role_id'], object: 'contributors', nested_attributes: true, name: 'role_id' },
  'contributor_role_vocabulary' => { from: ['contributor_role_vocabulary'], object: 'contributors', nested_attributes: true, name: 'role_vocabulary' },
  'contributor_name_identifier' => { from: ['contributor_name_identifier'], object: 'contributors', nested_attributes: true, name: 'name_identifier' },
  'contributor_scheme_uri' => { from: ['contributor_scheme_uri'], object: 'contributors', nested_attributes: true, name: 'scheme_uri' },
  'contributor_affiliation' => { from: ['contributor_affiliation'], object: 'contributors', nested_attributes: true, name: 'affiliation' },
  'contributor_affiliation_identifier' => { from: ['contributor_affiliation_identifier'], object: 'contributors', nested_attributes: true, name: 'affiliation_identifier' },
  # identifiers - value + type
  'identifier_value' => { from: ['identifier_value'], object: 'identifiers', nested_attributes: true, name: 'value' },
  'identifier_type' => { from: ['identifier_type'], object: 'identifiers', nested_attributes: true, name: 'type' },
  # funding_references - funder + award
  'funder_name' => { from: ['funder_name'], object: 'funding_references', nested_attributes: true, name: 'funder_name' },
  'funder_identifier' => { from: ['funder_identifier'], object: 'funding_references', nested_attributes: true, name: 'funder_identifier' },
  'funder_identifier_type' => { from: ['funder_identifier_type'], object: 'funding_references', nested_attributes: true, name: 'funder_identifier_type' },
  'funder_scheme_uri' => { from: ['funder_scheme_uri'], object: 'funding_references', nested_attributes: true, name: 'scheme_uri' },
  'funder_award_number' => { from: ['funder_award_number'], object: 'funding_references', nested_attributes: true, name: 'award_number' },
  'funder_award_uri' => { from: ['funder_award_uri'], object: 'funding_references', nested_attributes: true, name: 'award_uri' },
  'funder_award_title' => { from: ['funder_award_title'], object: 'funding_references', nested_attributes: true, name: 'award_title' },
  # organisational_units - ROR-backed org structure
  'organisational_unit_name' => { from: ['organisational_unit_name'], object: 'organisational_units', nested_attributes: true, name: 'name' },
  'organisational_unit_pid' => { from: ['organisational_unit_pid'], object: 'organisational_units', nested_attributes: true, name: 'pid' },
  'organisational_unit_type' => { from: ['organisational_unit_type'], object: 'organisational_units', nested_attributes: true, name: 'unit_type' },
  # licenses - stacked rights claims (PR Voices rightsList)
  'license_rights_label' => { from: ['license_rights_label'], object: 'licenses', nested_attributes: true, name: 'rights_label' },
  'license_rights_uri' => { from: ['license_rights_uri'], object: 'licenses', nested_attributes: true, name: 'rights_uri' },
  'license_holder' => { from: ['license_holder'], object: 'licenses', nested_attributes: true, name: 'holder' },
  'license_rights_identifier' => { from: ['license_rights_identifier'], object: 'licenses', nested_attributes: true, name: 'rights_identifier' },
  'license_rights_identifier_scheme' => { from: ['license_rights_identifier_scheme'], object: 'licenses', nested_attributes: true, name: 'rights_identifier_scheme' },
  'license_scheme_uri' => { from: ['license_scheme_uri'], object: 'licenses', nested_attributes: true, name: 'scheme_uri' },
  'license_lang' => { from: ['license_lang'], object: 'licenses', nested_attributes: true, name: 'lang' },
  # geo_locations - point or bounding box (Artefact + Event)
  'geo_place_name' => { from: ['geo_place_name'], object: 'geo_locations', nested_attributes: true, name: 'place_name' },
  'geo_point_latitude' => { from: ['geo_point_latitude'], object: 'geo_locations', nested_attributes: true, name: 'point_latitude' },
  'geo_point_longitude' => { from: ['geo_point_longitude'], object: 'geo_locations', nested_attributes: true, name: 'point_longitude' },
  'geo_west_bound' => { from: ['geo_west_bound'], object: 'geo_locations', nested_attributes: true, name: 'west_bound' },
  'geo_east_bound' => { from: ['geo_east_bound'], object: 'geo_locations', nested_attributes: true, name: 'east_bound' },
  'geo_south_bound' => { from: ['geo_south_bound'], object: 'geo_locations', nested_attributes: true, name: 'south_bound' },
  'geo_north_bound' => { from: ['geo_north_bound'], object: 'geo_locations', nested_attributes: true, name: 'north_bound' },
  # relationships - the patch cables (Object Handling Spec v0.2 Sec 3.5)
  'relationship_item' => { from: ['relationship_item'], object: 'relationships', nested_attributes: true, name: 'item' },
  'relationship_type' => { from: ['relationship_type'], object: 'relationships', nested_attributes: true, name: 'type' },
  'relationship_position' => { from: ['relationship_position'], object: 'relationships', nested_attributes: true, name: 'position' },
  'relationship_note' => { from: ['relationship_note'], object: 'relationships', nested_attributes: true, name: 'note' }
}

# Hyku's defaults ship sample-compound mappings (participants, identifiers,
# relationships) that read the same CSV columns as ours or target compounds the
# Enact profile does not declare. Drop them so a column like relationship_item
# is consumed exactly once, by our mapping. (`path`/`is_display_url` stay -
# redirects is a real Hyku feature, not a sample.)
HYKU_SAMPLE_COMPOUND_KEYS = %w[name role participant_title value identifier_type
                               item relationship_type relationship_title].freeze

mappings = Hyku.default_bulkrax_field_mappings.deep_dup
mappings.each_key do |parser|
  mappings[parser] = mappings[parser]
                     .except(*HYKU_SAMPLE_COMPOUND_KEYS)
                     .merge(compound_mappings)
end
Hyku.default_bulkrax_field_mappings = mappings
