# frozen_string_literal: true

# OVERRIDE Bulkrax CsvEntry to resolve a compound's `linked_record` member from a
# human-readable cell (the import CSV value) to the stored row id the show/edit
# pipeline expects. Bulkrax assembles the compound's `_attributes` hash with the
# raw cell still in the member slot; the resolver finds by id, so an unresolved
# string would never link. The per-cell matcher can't help — it sees only its own
# cell, not sibling identity/enrichment columns — so resolution runs here, after
# `build_metadata` has assembled the whole per-entry hash.
#
# Today the only linked_record compound is `contributors`. The resolution
# mechanics (resolve_linked_records!) are source-agnostic; the contributor
# specifics (which compound, source, member, and which carrier columns enrich the
# record) live in the single caller below. ADDING A SECOND linked_record compound
# (e.g. funders, places): register its source in enact_linked_records.rb, then add
# a `resolve_<thing>!` caller mirroring resolve_linked_contributors! — passing its
# attrs key, source, member name, and an extractor for its own enrichment carriers
# — and invoke it from build_metadata. The skeleton needs no change.
module Bulkrax
  module CsvEntryDecorator
    CONTRIBUTORS_ATTRS_KEY = 'contributors_attributes'
    CONTRIBUTOR_SOURCE = :contributors
    CONTRIBUTOR_MEMBER = 'contributor'
    # Per-entry separators for multi-valued carrier columns. `|` matches the
    # manifest's existing multi-value convention (keyword/publisher/related_item);
    # a name_identifier entry is `value;scheme` (`;` appears in neither an ORCID
    # URL nor an ISNI/ROR value). Shared by any compound's carrier parsing.
    ENTRY_DELIMITER = '|'
    PAIR_DELIMITER = ';'

    def build_metadata
      super
      resolve_linked_contributors!
      parsed_metadata
    end

    # The linked_record sub-property hash for a source, found in the profile by
    # its linked_record type + `authority:` + host `compound` rather than by key
    # name, so a profile rename of the sub-property key doesn't break import.
    # Sourced from the M3 profile on disk (the file EnactCompoundNormalization
    # loads), so an import decision needs no DB/schema context.
    def self.linked_record_member(source:, compound:)
      profile_properties.values.find do |config|
        config.is_a?(::Hash) &&
          config['type'] == 'linked_record' &&
          config['authority'].to_s == source.to_s &&
          Array(config.dig('available_on', 'properties')).include?(compound)
      end
    end

    # The M3 profile's `properties` hash, parsed once and memoized — build_metadata
    # runs per imported row, so reading and parsing the YAML each call would be a
    # per-row I/O + parse cost on large imports. The profile is static at runtime.
    def self.profile_properties
      @profile_properties ||= YAML.safe_load(::File.read(EnactCompoundNormalization::PROFILE_PATH))['properties'] || {}
    end

    private

    # --- contributor-specific caller -----------------------------------------

    def resolve_linked_contributors!
      resolve_linked_records!(
        attrs_key: CONTRIBUTORS_ATTRS_KEY,
        source: CONTRIBUTOR_SOURCE,
        member: CONTRIBUTOR_MEMBER,
        compound: 'contributors'
      ) { |entry| extract_contributor_attrs(entry) }
    end

    # Pull the contributor's identity + record attributes off the entry, deleting
    # each carrier (so the compound populator never receives them — only
    # `contributor`/`role`/`role_other` are real members). orcid is also a match
    # key; agent_type/affiliation/name_identifier are CREATE-ONLY enrichment. Only
    # keys actually present in the CSV are forwarded, so an absent column never
    # overwrites a model default with a blank.
    def extract_contributor_attrs(entry)
      attrs = { display_name: entry.delete(CONTRIBUTOR_MEMBER).to_s.strip }
      orcid = entry.delete('orcid').to_s.strip
      attrs[:orcid] = orcid if orcid.present?
      agent_type = entry.delete('agent_type').to_s.strip
      attrs[:agent_type] = agent_type if agent_type.present?
      attrs[:affiliations] = split_entries(entry.delete('affiliation')) if entry.key?('affiliation')
      attrs[:name_identifiers] = parse_name_identifiers(entry.delete('name_identifier')) if entry.key?('name_identifier')
      attrs
    end

    # --- source-agnostic skeleton --------------------------------------------

    # Resolve every assembled entry's linked_record member from a natural-key cell
    # to a stored row id. `attrs_for` (the block) extracts and deletes that
    # entry's identity + transient carrier values, returning the attrs hash for
    # the resolver; it must put the natural key under :display_name (the resolver
    # match/create contract). Enrichment is CREATE-ONLY: it reaches `create` only
    # on a miss, because find_or_create is `match || create`.
    #
    # `creatable:` is profile-driven per member: true -> find-or-create (a miss is
    # created); false/absent -> find-only (a miss is skipped + logged, never
    # fabricated). A blank natural key or a find-only miss drops the entry.
    def resolve_linked_records!(attrs_key:, source:, member:, compound:)
      entries = parsed_metadata[attrs_key]
      return unless entries.is_a?(Hash)

      creatable = member_creatable?(source:, compound:)
      entries.delete_if do |_index, entry|
        next false unless entry.is_a?(Hash)

        resolve_entry(entry, source:, member:, creatable:, attrs: yield(entry))
      end
    end

    # @return [Boolean] true to drop the entry (blank natural key, or find-only miss).
    def resolve_entry(entry, source:, member:, creatable:, attrs:)
      return true if attrs[:display_name].blank?

      record = find_or_create_record(source, attrs, creatable:)
      if record&.persisted?
        entry[member] = record.id.to_s
        return false
      end

      Rails.logger.warn(
        "CsvEntryDecorator: #{source} #{attrs[:display_name].inspect} has no matching record" \
        "#{' and could not be created' if creatable} — skipped."
      )
      true
    end

    # creatable -> find-or-create (a miss is created); find-only -> match only
    # (a miss returns nil and the caller skips the entry).
    def find_or_create_record(source, attrs, creatable:)
      if creatable
        Hyrax::CompoundLinkedRecordResolver.find_or_create(source, attrs)
      else
        Hyrax::CompoundLinkedRecordResolver.match(source, attrs)
      end
    end

    def member_creatable?(source:, compound:)
      member = Bulkrax::CsvEntryDecorator.linked_record_member(source:, compound:)
      member.present? && member['creatable'] == true
    end

    # --- carrier parsing (shared) --------------------------------------------

    # A `|`-separated multi-value cell into a compacted array of strings.
    def split_entries(value)
      value.to_s.split(ENTRY_DELIMITER).map(&:strip).reject(&:blank?)
    end

    # A `|`-separated list of `value;scheme` pairs into [{value:, scheme:}, …]; a
    # pair missing its scheme keeps a blank scheme (the model drops blank-value
    # entries on write).
    def parse_name_identifiers(value)
      split_entries(value).map do |pair|
        val, scheme = pair.split(PAIR_DELIMITER, 2).map { |s| s.to_s.strip }
        { value: val, scheme: }
      end
    end
  end
end

Bulkrax::CsvEntry.prepend(Bulkrax::CsvEntryDecorator)
