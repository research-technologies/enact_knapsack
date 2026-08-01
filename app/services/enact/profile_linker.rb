# frozen_string_literal: true

module Enact
  # Finds the profiles that might belong to a given User, and builds one from
  # their account fields when none does.
  #
  # The tiers are ordered by confidence: an ORCID match is the same person by
  # definition, a fuzzy name match is a guess, and a manual search is whatever
  # the admin went looking for.
  class ProfileLinker
    SEARCH_LIMIT = 20

    def initialize(user)
      @user = user
    end

    def orcid_match
      return nil if orcid.blank?

      @orcid_match ||= Contributor.unclaimed.where('LOWER(orcid) = LOWER(?)', orcid).order(:id).first
    end

    # A profile with this ORCID that ANOTHER user already holds. Creating from
    # the snapshot would hit the unique ORCID index, so the caller warns instead
    # of letting the admin meet a bare "Orcid has already been taken".
    def orcid_conflict
      return nil if orcid.blank?

      Contributor.claimed.where('LOWER(orcid) = LOWER(?)', orcid).order(:id).first
    end

    # Minus the ORCID hit, which is already shown above these.
    def suggestions
      Contributor.unclaimed.similar_to(search_name).reject { |c| c.id == orcid_match&.id }
    end

    # Both scopes, because neither alone is enough: `matching` is the only tier
    # that finds an ORCID or affiliation (it searches the metadata blob) but
    # cannot survive a typo, while `similar_to` catches Jon/John but knows
    # nothing about affiliations. An admin typing here is often searching
    # *because* the automatic tiers missed.
    #
    # Substring hits rank first — an exact fragment the admin typed is a stronger
    # signal than a fuzzy name.
    def search(term)
      return nil if term.blank?

      substring = Contributor.matching(term).order(:display_name).limit(SEARCH_LIMIT).to_a
      fuzzy = Contributor.similar_to(term).to_a
      seen = substring.map(&:id).to_set
      (substring + fuzzy.reject { |c| seen.include?(c.id) }).first(SEARCH_LIMIT)
    end

    # A SNAPSHOT, not a sync: nothing re-copies these later. The account's email,
    # department, title, office, telephone and website are deliberately dropped —
    # Contributor has no home for them, and stashing them in the metadata blob
    # would create a second source of truth that goes stale the first time the
    # user edits their account.
    #
    # display_name is left BLANK when the account has none. Most Hyku accounts
    # never set one
    def build_profile
      profile = Contributor.new(display_name: @user.display_name.presence,
                                orcid: orcid.presence,
                                agent_type: 'person')
      profile.affiliations = Array(@user.affiliation).compact_blank
      profile
    end

    private

    def orcid
      @orcid ||= @user.orcid.to_s.strip
    end

    # Fall back to the email's local part so a user who never set a display name
    # still gets useful fuzzy suggestions.
    def search_name
      @user.display_name.presence || @user.email.to_s.split('@').first
    end
  end
end
