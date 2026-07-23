# frozen_string_literal: true

module Enact
  # Reads a work's `contributors` compound into a per-contributor view for the
  # show-page contributors card. The display counterpart of
  # Enact::ContributorGraph (which answers the reverse question — the works a
  # given contributor is credited on).
  #
  # Groups the compound entries by contributor id so each person/organization is
  # shown once with all of its roles, rather than the generic compound renderer's
  # one-row-per-entry, which repeats the name.
  #
  # Each contributor id is resolved through Hyrax::CompoundLinkedRecordResolver
  # (label + profile path) and the Enact::Contributor record (ORCID, agent type);
  # an id that no longer resolves to a contributor is rendered as a bare label so
  # the card never emits a broken link.
  class WorkContributors
    SOURCE = :contributors

    Credit = Struct.new(:id, :label, :path, :orcid, :agent_type, :roles, :role_other, keyword_init: true)

    # @param document [SolrDocument, #contributors] the work whose contributors we render
    def initialize(document)
      @document = document
    end

    # One Credit per distinct contributor, in first-appearance order, each
    # carrying all of that contributor's role codes (and any free-text roles) on
    # this work.
    # @return [Array<Credit>]
    def credits
      grouped = entries.each_with_object({}) do |entry, memo|
        id = entry['contributor'].to_s
        next if id.blank?

        bucket = (memo[id] ||= { roles: [], role_other: [] })
        # Array() tolerates roles saved as a single string before the multi-select opt-in.
        bucket[:roles].concat(Array(entry['role']).reject(&:blank?))
        bucket[:role_other] << entry['role_other'] if entry['role_other'].present?
      end

      grouped.map { |id, data| build_credit(id, data) }
    end

    private

    # Parse the work's `contributors` compound into entry hashes. A SolrDocument
    # exposes a coerced `contributors` reader; a raw hit only carries the
    # `_json_ss` blob, so coerce it directly. Mirrors
    # Enact::ContributorGraph#contributor_entries.
    def entries
      return Array(@document.contributors) if @document.respond_to?(:contributors)

      blob = @document['contributors_json_ss'] if @document.respond_to?(:[])
      Hyrax::SolrDocument::Metadata::Solr::CompoundEntries.coerce(blob)
    end

    def build_credit(id, data)
      record = Hyrax::CompoundLinkedRecordResolver.find(SOURCE, id)
      label, path = Hyrax::CompoundLinkedRecordResolver.title_and_path(SOURCE, id, label_field: :display_name)
      Credit.new(
        id:,
        label:,
        path:,
        orcid: record.try(:orcid).presence,
        agent_type: record.try(:agent_type),
        roles: data[:roles],
        role_other: data[:role_other]
      )
    end
  end
end
