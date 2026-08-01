# frozen_string_literal: true

module Enact
  # A lightweight, editable contributor profile, independent of the Hyrax User.
  # A contributor may have no login and no email; a User is involved only when a
  # contributor is *claimed*, which links the two 1:1 via `user_id` and lets that
  # user curate their own profile. Claiming is admin-approved — see
  # Enact::ProfileRequest.
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

    # The Hyku User who has claimed this profile, if any. Optional: most profiles
    # describe people with no login at all. No FK — deleting a user must not
    # cascade into deleting a curated profile (see #linked_user).
    belongs_to :user, optional: true, inverse_of: :enact_contributor

    validates :display_name, presence: true

    # One profile per user (a partial unique index is the DB-level guarantee;
    # this surfaces a clean error rather than a raw constraint violation).
    validates :user_id, uniqueness: true, allow_nil: true

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

    # Unclaimed contributors are those not yet linked to a User.
    scope :unclaimed, -> { where(user_id: nil) }
    scope :claimed, -> { where.not(user_id: nil) }

    # Case-insensitive match on display_name, orcid, or any value in the metadata
    # blob (affiliations and name_identifiers). The blob is matched as text
    # (`metadata::text`), so a substring hit on a jsonb key or scheme label is a
    # possible over-match — rare and harmless at current volumes. LIKE wildcards in
    # the term are escaped. Shared by the browse index and the picker search.
    scope :matching, lambda { |term|
      escaped = sanitize_sql_like(term.to_s.strip)
      where('display_name ILIKE :t OR orcid ILIKE :t OR metadata::text ILIKE :t', t: "%#{escaped}%")
    }

    # Trigram-fuzzy name match (pg_trgm) for the create-form duplicate check,
    # catching typos and spelling variants (Jon↔John, Smyth↔Smith) that the
    # substring `matching` scope misses. Kept distinct from `matching` on purpose:
    # the live typeahead wants fast substring results, this "did you mean" check
    # wants fuzzy recall on a complete name. Empty for a blank term.
    SIMILAR_NAME_THRESHOLD = 0.3
    scope :similar_to, lambda { |term|
      name = term.to_s.strip
      next none if name.blank?

      where('similarity(display_name, :n) >= :threshold', n: name, threshold: SIMILAR_NAME_THRESHOLD)
        .order(Arel.sql(sanitize_sql_array(['similarity(display_name, ?) DESC', name])))
        .limit(10)
    }

    def claimed?
      user_id.present?
    end

    # The linked User, or nil when `user_id` points at a deleted account. There
    # is no FK on `user_id` (a FK would force either cascading the delete onto a
    # curated profile or blocking user deletion), so a dangling id is expected
    # and must read back safely.
    def linked_user
      return nil if user_id.blank?

      @linked_user ||= ::User.find_by(id: user_id)
    end

    # Ownership only — the edit policy that consumes it lives in
    # Hyrax::Ability::ContributorAbility. `candidate.present?` is load-bearing,
    # not defensive noise: Ability is built with a nil user for anonymous
    # visitors, and `nil.id` would raise instead of returning false.
    def editable_by?(candidate)
      candidate.present? && user_id.present? && user_id == candidate.id
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
