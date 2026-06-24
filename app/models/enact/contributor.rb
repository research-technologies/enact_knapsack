# frozen_string_literal: true

module Enact
  # A lightweight, editable contributor profile, independent of the Hyrax User.
  # A contributor may have no login and no email; a User is involved only when a
  # contributor is later *claimed* (the `user_id` column is reserved for that and
  # unused in Phase 1).
  #
  # Typed single table: `agent_type` distinguishes a person from an organization
  # so both share one model, picker, and reverse-lookup. Type-varying and
  # extensible attributes (`affiliations`, and general `name_identifiers` —
  # {value, scheme} pairs such as ISNI/VIAF/ROR, distinct from the dedicated
  # `orcid` column) live in the `metadata` jsonb blob rather than as fixed
  # columns, so adding identifier kinds needs no migration.
  class Contributor < HykuKnapsack::ApplicationRecord
    self.table_name = 'enact_contributors'

    enum :agent_type, { person: 'person', organization: 'organization' }, default: 'person'

    validates :display_name, presence: true

    # Optional, but unique when present (a partial unique index is the DB-level
    # guarantee; this surfaces a clean error rather than a raw constraint violation).
    validates :orcid, uniqueness: { case_sensitive: false }, allow_nil: true

    # The enum `default:` only applies when `agent_type` is never assigned; a
    # form that submits a blank select option assigns "" and clobbers it, hitting
    # the NOT NULL column. Coerce any blank value back to the default so every
    # write path (inline picker, profile edit, import) is safe.
    before_validation { self.agent_type = 'person' if agent_type.blank? }

    # A blank ORCID is stored as NULL, not "", so ORCID-less contributors stay
    # outside the uniqueness constraint instead of colliding as empty strings.
    before_validation { self.orcid = nil if orcid.blank? }

    # Affiliations are multi-valued, stored as an array under the `affiliation`
    # jsonb key. The reader coerces for backward compatibility: a value saved as
    # a single string (the previous shape) reads back as a one-element array, so
    # no data migration is needed. The writer always stores a compacted array of
    # non-blank strings.
    def affiliations
      Array(metadata['affiliation']).map(&:to_s).reject(&:blank?)
    end

    def affiliations=(values)
      metadata['affiliation'] = Array(values).map { |v| v.to_s.strip }.reject(&:blank?)
    end

    # Name identifiers are multi-valued: a list of { 'value' =>, 'scheme' => }
    # hashes (e.g. ISNI/VIAF/ROR), separate from the dedicated `orcid`. The
    # reader coerces a legacy single `name_identifier` (+ scheme) into a
    # one-element list, so records saved under the old single-identifier shape
    # read back without a data migration. The writer normalizes any
    # array-of-hashes (string- or symbol-keyed) and drops blank-value entries.
    def name_identifiers
      stored = metadata['name_identifiers'].presence || legacy_name_identifier
      normalize_name_identifiers(stored)
    end

    def name_identifiers=(entries)
      metadata['name_identifiers'] = normalize_name_identifiers(entries)
      # Drop the legacy single-identifier keys once the list is set authoritatively.
      metadata.delete('name_identifier')
      metadata.delete('name_identifier_scheme')
    end

    # Unclaimed contributors are those not yet linked to a User. Claiming (a
    # future flow) sets `user_id`.
    scope :unclaimed, -> { where(user_id: nil) }
    scope :claimed, -> { where.not(user_id: nil) }

    # Case-insensitive match on display_name OR orcid; LIKE wildcards in the term
    # are escaped so `%`/`_` are treated literally. Shared by the browse index
    # search and the contributors linked-record search.
    scope :matching, lambda { |term|
      escaped = sanitize_sql_like(term.to_s.strip)
      where('display_name ILIKE :t OR orcid ILIKE :t', t: "%#{escaped}%")
    }

    def claimed?
      user_id.present?
    end

    private

    # The legacy single `name_identifier` (+ scheme) as a one-element list, so
    # records saved under the old single-identifier shape read back without a
    # data migration. Empty when no legacy value is stored.
    def legacy_name_identifier
      return [] if metadata['name_identifier'].blank?

      [{ 'value' => metadata['name_identifier'], 'scheme' => metadata['name_identifier_scheme'] }]
    end

    # Coerce an array of {value, scheme} entries (string- or symbol-keyed) into
    # canonical string-keyed hashes, trimming and dropping blank-value entries.
    def normalize_name_identifiers(entries)
      Array(entries).filter_map do |entry|
        next unless entry.respond_to?(:[])

        value = (entry['value'] || entry[:value]).to_s.strip
        next if value.blank?

        { 'value' => value, 'scheme' => (entry['scheme'] || entry[:scheme]).to_s.strip.presence }
      end
    end
  end
end
