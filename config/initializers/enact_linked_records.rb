# frozen_string_literal: true

# Register Enact's linked_record sources with the generic
# Hyrax::CompoundLinkedRecordResolver. Each source maps a stored reference (a
# row id) to a record, a display label, a show path, a table search (for the
# picker autocomplete), an inline create, and an exact match (for find-or-create
# on import). The resolver stays generic; this is where Enact says "the
# :contributors source is Enact::Contributor".
#
# The procs are defined as module functions so the registration call below reads
# as a summary of the source's capabilities; they are wired up inside to_prepare
# so the binding re-runs on code reload and resolves the model/route lazily.
#
# ADDING A SECOND linked_record source (e.g. funders, places): add a sibling
# module of the same procs and a matching `register(:source, …)` call in the same
# to_prepare. `match:` is what import find-or-create needs (exact, single-row);
# omit it for a source that should never be matched-on-import. Then add its import
# field mappings (config/initializers/bulkrax.rb) and a resolve_<thing>! caller in
# the CsvEntry decorator.
module Enact
  module ContributorSource
    module_function

    def finder(id)
      Enact::Contributor.find_by(id:)
    end

    def label(contributor)
      contributor.display_name
    end

    def path(contributor)
      HykuKnapsack::Engine.routes.url_helpers.enact_contributor_path(contributor)
    end

    # Picker autocomplete: the generic linked_record QA authority
    # (/authorities/search/linked_record/contributors) delegates here. Match on
    # name or ORCID via the model scope; shape each row for select2.
    def search(query)
      Enact::Contributor.matching(query).order(:display_name).limit(20).map do |contributor|
        { id: contributor.id.to_s, label: contributor.display_name, value: contributor.id.to_s }
      end
    end

    # Inline lookup-OR-create: the generic endpoint hands us the submitted
    # attributes; we create the contributor. The create-form field list itself
    # is declared in the m3 profile (create_fields); here we map those fields to
    # the model. `affiliations` is a repeatable scalar (an Array of strings) and
    # `name_identifiers` a repeatable group (an Array of {value, scheme} hashes);
    # both feed the model's multi-valued writers.
    def create(attrs)
      attrs = indifferent(attrs)
      contributor = Enact::Contributor.new(attrs.slice(:display_name, :orcid, :agent_type))
      contributor.affiliations = attrs[:affiliations] if attrs.key?(:affiliations)
      contributor.name_identifiers = attrs[:name_identifiers] if attrs.key?(:name_identifiers)
      contributor.tap(&:save)
    end

    # Exact, single-row lookup for find-or-create on import (distinct from the
    # fuzzy multi-row `search`, which is for the human-driven picker). An ORCID is
    # the stronger identity, so it wins when present AND it hits; a
    # present-but-unmatched ORCID falls through to the name so a new ORCID on an
    # existing name links to that person rather than creating a duplicate. When no
    # ORCID is given (e.g. the import CSV omits the column) the match is by name
    # alone. Both comparisons are exact and case-insensitive; order(:id) makes the
    # result deterministic if legacy duplicates exist.
    def match(attrs)
      attrs = indifferent(attrs)
      orcid = attrs[:orcid].to_s.strip
      if orcid.present?
        found = Enact::Contributor.where('LOWER(orcid) = LOWER(?)', orcid).order(:id).first
        return found if found
      end
      name = attrs[:display_name].to_s.strip
      return nil if name.blank?

      Enact::Contributor.where('LOWER(display_name) = LOWER(?)', name).order(:id).first
    end

    # Accept symbol- or string-keyed attrs (and ActionController::Parameters):
    # the import decorator passes symbols and the Hyrax create endpoint already
    # deep-symbolizes, but normalizing here keeps both procs working for any
    # caller rather than silently reading every key as blank.
    def indifferent(attrs)
      raw = attrs.respond_to?(:to_unsafe_h) ? attrs.to_unsafe_h : attrs
      raw.to_h.with_indifferent_access
    end
  end
end

Rails.application.config.to_prepare do
  src = Enact::ContributorSource
  Hyrax::CompoundLinkedRecordResolver.register(
    :contributors,
    finder: src.method(:finder), label: src.method(:label), path: src.method(:path),
    search: src.method(:search), create: src.method(:create), match: src.method(:match)
  )
end
