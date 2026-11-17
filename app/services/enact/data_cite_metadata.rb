# frozen_string_literal: true

module Enact
  # Supplies the :creator and :publisher values for hyrax-pid's DataCite
  # field_mapping (see config/initializers/hyrax_pid.rb and
  # Hyrax::Pid::DataCite::MetadataMapper) from a work's `contributors`
  # compound -- Enact has no flat `publisher` field in general use (M3 only
  # declares one on Portfolio, and even that's not guaranteed to last), and
  # "who published this" is instead just another contributor credit, tagged
  # with a PUBLISHER_ROLES code.
  #
  # DataCite's `publisher` is a separate top-level property, not a
  # contributorType -- so a contributors entry tagged with a publisher role
  # never becomes a DataCite Contributor, only the top-level publisher name.
  module DataCiteMetadata
    # Contributor roles that make an entry a DataCite Creator rather than a
    # plain contributor. Starting narrow on purpose -- there will be opinions
    # on this list; widen it here, not by rewriting the filtering logic.
    CREATOR_ROLES = %w[author creator].freeze

    # Contributor roles that identify a work's publisher (not a DataCite
    # contributorType -- see the class comment above).
    PUBLISHER_ROLES = %w[publisher publishedby].freeze

    module_function

    # @param work [#contributors]
    # @return [Array<Hash>] a DataCite creator object per contributors entry
    #   tagged with a CREATOR_ROLES code; empty if none (the metadata mapper
    #   treats an empty Array as a missing required field)
    def creators_for(work)
      contributor_entries(work).select { |entry| creator_role?(entry) }
                                .filter_map { |entry| creator_hash(entry) }
    end

    # @param work [#contributors]
    # @return [String, nil] the display name of the first contributor tagged
    #   with a PUBLISHER_ROLES code, or nil if there isn't one (the metadata
    #   mapper treats nil as a missing required field and fails loudly)
    def publisher_for(work)
      entry = contributor_entries(work).find { |e| publisher_role?(e) }
      resolve(entry)&.display_name if entry
    end

    def contributor_entries(work)
      Array(work.try(:contributors))
    end

    def creator_role?(entry)
      roles(entry).any? { |role| CREATOR_ROLES.include?(role) }
    end

    def publisher_role?(entry)
      roles(entry).any? { |role| PUBLISHER_ROLES.include?(role) }
    end

    # A compound entry's roles, as the bare authority codes ("author"), read
    # tolerantly: the live Valkyrie resource attribute and a value round-
    # tripped through Solr/import don't reliably agree on symbol vs. string
    # keys (see Enact::WorkContributors/Enact::ContributorGraph, which have
    # the same tolerance for their own, Solr-only, read paths).
    def roles(entry)
      Array(fetch(entry, :role)).map(&:to_s)
    end

    def resolve(entry)
      id = fetch(entry, :contributor)
      return nil if id.blank?

      Hyrax::CompoundLinkedRecordResolver.find(:contributors, id)
    end

    def creator_hash(entry)
      contributor = resolve(entry)
      return nil unless contributor

      hash = {name: contributor.display_name, nameType: contributor.organization? ? "Organizational" : "Personal"}
      identifiers = name_identifiers(contributor)
      hash[:nameIdentifiers] = identifiers if identifiers.any?
      affiliations = affiliation_list(contributor)
      hash[:affiliation] = affiliations if affiliations.any?
      hash
    end

    # ORCID has its own dedicated column/scheme on Enact::Contributor;
    # everything else (ISNI/VIAF/ROR/Other) lives in its general
    # name_identifiers list -- combine both into one DataCite nameIdentifiers
    # array.
    def name_identifiers(contributor)
      identifiers = []
      if contributor.orcid.present?
        identifiers << {nameIdentifier: contributor.orcid, nameIdentifierScheme: "ORCID", schemeUri: "https://orcid.org"}
      end
      Array(contributor.name_identifiers).each do |entry|
        value = (entry["value"] || entry[:value]).to_s
        next if value.blank?

        scheme = (entry["scheme"] || entry[:scheme]).presence || "Other"
        identifiers << {nameIdentifier: value, nameIdentifierScheme: scheme}
      end
      identifiers
    end

    def affiliation_list(contributor)
      Array(contributor.affiliations).reject(&:blank?).map { |name| {name: name} }
    end

    def fetch(entry, key)
      entry[key] || entry[key.to_s]
    end
  end
end
