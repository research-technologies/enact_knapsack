# frozen_string_literal: true

module Enact
  # The works a contributor is credited on, for the contributor profile page.
  #
  # A credit is stored once, on the work's `contributors` compound, as an entry
  # keyed by the M3 members' `name:`s ({"contributor", "role"}). A contributor
  # carries no list of its own works; they are found with a Solr reverse lookup
  # on `contributors_contributor_ssim` (the derived index field for the
  # `contributor` member) — the same single-source-of-truth design as
  # {Enact::RelationshipGraph}.
  #
  # The lookup is access-scoped to the supplied ability, so a profile page only
  # lists works the viewer is allowed to see. Each work appears once, with all of
  # this contributor's roles on it collected (a person can hold several CRediT
  # roles on the same work).
  class ContributorGraph
    # A work this contributor is credited on.
    Credit = Struct.new(:id, :title, :path, :roles, :role_other, :thumbnail, :type_label, keyword_init: true)

    # @param contributor [Enact::Contributor, #id]
    # @param ability [Ability] the viewer's abilities; the reverse lookup is
    #   scoped to works this ability can :read.
    def initialize(contributor, ability:)
      @contributor = contributor
      @ability = ability
    end

    # @return [Array<Credit>] one per accessible work crediting the contributor,
    #   ordered by title.
    def works
      id = @contributor.id
      return [] if id.blank?

      docs = accessible_docs_crediting(id.to_s)
      credits = docs.filter_map { |doc| build_credit(doc, id.to_s) }
      credits.sort_by { |credit| credit.title.to_s.downcase }
    end

    private

    # Works whose `contributors` compound names this contributor, scoped to the
    # viewer's ability.
    def accessible_docs_crediting(id)
      Hyrax::SolrQueryService.new
                             .with_field_pairs(field_pairs: { 'contributors_contributor_ssim' => id })
                             .accessible_by(ability: @ability)
                             .solr_documents(rows: 1_000)
    end

    # Build a Credit from a work doc, collecting both the controlled roles and
    # the free-text role_other whose entry belongs to this contributor. The view
    # renders both as role badges (controlled codes via ContributorRolesService,
    # role_other verbatim), so a credit whose only role is free text still shows
    # a role — mirroring the work-side Enact::WorkContributors card.
    def build_credit(doc, id)
      ours = contributor_entries(doc).select { |entry| entry['contributor'].to_s == id }
      Credit.new(
        id: doc.id,
        title: Array(doc['title_tesim']).first.to_s,
        path: Hyrax::CompoundWorkResolver.path_for(doc.id),
        roles: ours.filter_map { |entry| entry['role'].presence },
        role_other: ours.filter_map { |entry| entry['role_other'].presence },
        # The work's indexed thumbnail (thumbnail_path_ss), exposed by
        # SolrDocument#thumbnail_path; nil for a raw hit without the reader.
        thumbnail: (doc.thumbnail_path if doc.respond_to?(:thumbnail_path)),
        # The localized work-type label (e.g. "Artefact"), from the indexed
        # human_readable_type_tesim via SolrDocument#human_readable_type.
        type_label: (doc.human_readable_type if doc.respond_to?(:human_readable_type))
      )
    end

    # Parse a doc's `contributors` compound into an Array of entry hashes. A
    # SolrDocument defines a per-instance `contributors` reader in #initialize
    # (define_compound_readers! over its `_json_ss` keys), which #solr_documents
    # returns; the raw-blob branch is the fallback for a bare SolrService hit.
    # Keys come back as strings either way.
    def contributor_entries(doc)
      return Array(doc.contributors) if doc.respond_to?(:contributors)

      blob = doc['contributors_json_ss'] if doc.respond_to?(:[])
      Hyrax::SolrDocument::Metadata::Solr::CompoundEntries.coerce(blob)
    end
  end
end
