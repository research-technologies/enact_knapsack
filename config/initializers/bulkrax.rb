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

# Each compound's column family is its own hash, composed into compound_mappings
# below. Adding a compound = add a hash here + include it in the merge; the
# Hyku-default reconciliation at the bottom is untouched.

# titles - repeatable typed titles
title_mappings = {
  'title_value' => { from: ['title_value'], object: 'titles', nested_attributes: true, name: 'value' },
  'title_type' => { from: ['title_type'], object: 'titles', nested_attributes: true, name: 'type' },
  'title_lang' => { from: ['title_lang'], object: 'titles', nested_attributes: true, name: 'lang' }
}

# dates - typed dates
date_mappings = {
  'date_start' => { from: ['date_start'], object: 'dates', nested_attributes: true, name: 'start_date' },
  'date_end' => { from: ['date_end'], object: 'dates', nested_attributes: true, name: 'end_date' },
  'date_type' => { from: ['date_type'], object: 'dates', nested_attributes: true, name: 'type' },
  'date_information' => { from: ['date_information'], object: 'dates', nested_attributes: true, name: 'information' }
}

# linked_record compounds (generic)
# ----------------------------------
# A linked_record member stores a row id, but the CSV carries a human-readable
# natural key (e.g. a name). The knapsack CsvEntry decorator resolves that cell to
# the stored row id (find-or-create) AFTER Bulkrax assembles the compound, since a
# per-cell matcher can't see sibling columns. A compound may also map "carrier"
# columns: values that belong to the linked record itself, not the compound — the
# decorator consumes and DROPS them (create-only enrichment of the resolved row),
# so a carrier column is inert unless the decorator's extractor for that compound
# reads it. Multi-value carriers use `|`. Each linked_record compound is mapped as
# its own hash, the same way as contributors below.

# contributors - a linked_record reference to an Enact::Contributor plus a typed
# role. Real compound members: `contributor` (the resolved row id), `role`,
# `role_other`. Carriers (dropped after enriching the contributor record):
# `orcid` (also the match key), `agent_type`, and the multi-valued `affiliation` /
# `name_identifier` (a name_identifier entry is `value;scheme`).
contributor_mappings = {
  'contributor' => { from: ['contributor'], object: 'contributors', nested_attributes: true, name: 'contributor' },
  'contributor_orcid' => { from: ['contributor_orcid'], object: 'contributors', nested_attributes: true, name: 'orcid' },
  'contributor_agent_type' => { from: ['contributor_agent_type'], object: 'contributors', nested_attributes: true, name: 'agent_type' },
  'contributor_affiliation' => { from: ['contributor_affiliation'], object: 'contributors', nested_attributes: true, name: 'affiliation' },
  'contributor_name_identifier' => { from: ['contributor_name_identifier'], object: 'contributors', nested_attributes: true, name: 'name_identifier' },
  'contributor_role' => { from: ['contributor_role'], object: 'contributors', nested_attributes: true, name: 'role' },
  'contributor_role_other' => { from: ['contributor_role_other'], object: 'contributors', nested_attributes: true, name: 'role_other' }
}

# identifiers - value + type
identifier_mappings = {
  'identifier_value' => { from: ['identifier_value'], object: 'identifiers', nested_attributes: true, name: 'value' },
  'identifier_type' => { from: ['identifier_type'], object: 'identifiers', nested_attributes: true, name: 'type' }
}

# funding_references - funder + award
funding_reference_mappings = {
  'funder_name' => { from: ['funder_name'], object: 'funding_references', nested_attributes: true, name: 'funder_name' },
  'funder_identifier' => { from: ['funder_identifier'], object: 'funding_references', nested_attributes: true, name: 'funder_identifier' },
  'funder_identifier_type' => { from: ['funder_identifier_type'], object: 'funding_references', nested_attributes: true, name: 'funder_identifier_type' },
  'funder_scheme_uri' => { from: ['funder_scheme_uri'], object: 'funding_references', nested_attributes: true, name: 'scheme_uri' },
  'funder_award_number' => { from: ['funder_award_number'], object: 'funding_references', nested_attributes: true, name: 'award_number' },
  'funder_award_uri' => { from: ['funder_award_uri'], object: 'funding_references', nested_attributes: true, name: 'award_uri' },
  'funder_award_title' => { from: ['funder_award_title'], object: 'funding_references', nested_attributes: true, name: 'award_title' }
}

# organisational_units - ROR-backed org structure
organisational_unit_mappings = {
  'organisational_unit_name' => { from: ['organisational_unit_name'], object: 'organisational_units', nested_attributes: true, name: 'name' },
  'organisational_unit_pid' => { from: ['organisational_unit_pid'], object: 'organisational_units', nested_attributes: true, name: 'pid' },
  'organisational_unit_type' => { from: ['organisational_unit_type'], object: 'organisational_units', nested_attributes: true, name: 'unit_type' }
}

# licenses - stacked rights claims (PR Voices rightsList)
license_mappings = {
  'license_rights_label' => { from: ['license_rights_label'], object: 'licenses', nested_attributes: true, name: 'rights_label' },
  'license_rights_uri' => { from: ['license_rights_uri'], object: 'licenses', nested_attributes: true, name: 'rights_uri' },
  'license_holder' => { from: ['license_holder'], object: 'licenses', nested_attributes: true, name: 'holder' },
  'license_rights_identifier' => { from: ['license_rights_identifier'], object: 'licenses', nested_attributes: true, name: 'rights_identifier' },
  'license_rights_identifier_scheme' => { from: ['license_rights_identifier_scheme'], object: 'licenses', nested_attributes: true, name: 'rights_identifier_scheme' },
  'license_scheme_uri' => { from: ['license_scheme_uri'], object: 'licenses', nested_attributes: true, name: 'scheme_uri' },
  'license_lang' => { from: ['license_lang'], object: 'licenses', nested_attributes: true, name: 'lang' }
}

# geo_locations - point or bounding box (Artefact + Event)
geo_location_mappings = {
  'geo_place_name' => { from: ['geo_place_name'], object: 'geo_locations', nested_attributes: true, name: 'place_name' },
  'geo_point_latitude' => { from: ['geo_point_latitude'], object: 'geo_locations', nested_attributes: true, name: 'point_latitude' },
  'geo_point_longitude' => { from: ['geo_point_longitude'], object: 'geo_locations', nested_attributes: true, name: 'point_longitude' },
  'geo_west_bound' => { from: ['geo_west_bound'], object: 'geo_locations', nested_attributes: true, name: 'west_bound' },
  'geo_east_bound' => { from: ['geo_east_bound'], object: 'geo_locations', nested_attributes: true, name: 'east_bound' },
  'geo_south_bound' => { from: ['geo_south_bound'], object: 'geo_locations', nested_attributes: true, name: 'south_bound' },
  'geo_north_bound' => { from: ['geo_north_bound'], object: 'geo_locations', nested_attributes: true, name: 'north_bound' }
}

# relationships - the patch cables (Object Handling Spec v0.2 Sec 3.5)
relationship_mappings = {
  'relationship_item' => { from: ['relationship_item'], object: 'relationships', nested_attributes: true, name: 'item' },
  'relationship_type' => { from: ['relationship_type'], object: 'relationships', nested_attributes: true, name: 'type' },
  'relationship_position' => { from: ['relationship_position'], object: 'relationships', nested_attributes: true, name: 'position' },
  'relationship_note' => { from: ['relationship_note'], object: 'relationships', nested_attributes: true, name: 'note' }
}

compound_mappings = [
  title_mappings, date_mappings, contributor_mappings, identifier_mappings,
  funding_reference_mappings, organisational_unit_mappings, license_mappings,
  geo_location_mappings, relationship_mappings
].reduce(:merge)

# Hyku's defaults ship their own sample-compound mappings for some of the same
# CSV columns we map here. Rather than maintain a hand-written list of keys to
# drop (which drifts as Hyku's defaults change), derive it per parser: drop the
# Hyku default keys our `compound_mappings` also defines, then merge ours in, so
# each shared column is consumed exactly once by our mapping. Redirects keys
# (`path` / `is_display_url`) and any Hyku mapping we do not redefine are left
# untouched.
mappings = Hyku.default_bulkrax_field_mappings.deep_dup
mappings.each_key do |parser|
  overlapping = mappings[parser].keys & compound_mappings.keys
  mappings[parser] = mappings[parser]
                     .except(*overlapping)
                     .merge(compound_mappings)
end
Hyku.default_bulkrax_field_mappings = mappings
