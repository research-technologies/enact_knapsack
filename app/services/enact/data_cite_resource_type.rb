# frozen_string_literal: true

module Enact
  # Maps a work's `item_subtype` onto DataCite's resourceTypeGeneral
  # controlled vocabulary, for hyrax-pid's DataCite field_mapping (see
  # config/initializers/hyrax_pid.rb).
  #
  # item_subtype draws from four authorities, one per work type
  # (config/authorities/{artefact,literature,collection,event}_type.yml), and
  # some of their terms already cite the DataCite schema directly in their
  # own `id` -- e.g.
  # "https://datacite-metadata-schema.readthedocs.io/en/4.5/appendices/appendix-1/resourceTypeGeneral/#physicalobject".
  # Reusing that reference, instead of defaulting every work to "Other", is
  # the whole point of this mapping. A term with no such reference (most
  # COAR/Getty AAT/schema.org-sourced terms) still falls back to "Other" --
  # this deliberately doesn't attempt its own crosswalk from those
  # vocabularies, only from what the data already asserts.
  module DataCiteResourceType
    # DataCite's controlled resourceTypeGeneral vocabulary (schema 4.4-4.7),
    # keyed by the lowercase fragment the schema docs use in their own anchor
    # URLs -- exactly what the authority `id`s above reference.
    GENERAL_BY_FRAGMENT = {
      "audiovisual" => "Audiovisual",
      "award" => "Award",
      "book" => "Book",
      "bookchapter" => "BookChapter",
      "collection" => "Collection",
      "computationalnotebook" => "ComputationalNotebook",
      "conferencepaper" => "ConferencePaper",
      "conferenceproceeding" => "ConferenceProceeding",
      "datapaper" => "DataPaper",
      "dataset" => "Dataset",
      "dissertation" => "Dissertation",
      "event" => "Event",
      "image" => "Image",
      "interactiveresource" => "InteractiveResource",
      "instrument" => "Instrument",
      "journal" => "Journal",
      "journalarticle" => "JournalArticle",
      "model" => "Model",
      "outputmanagementplan" => "OutputManagementPlan",
      "peerreview" => "PeerReview",
      "physicalobject" => "PhysicalObject",
      "preprint" => "Preprint",
      "project" => "Project",
      "report" => "Report",
      "service" => "Service",
      "software" => "Software",
      "sound" => "Sound",
      "standard" => "Standard",
      "studyregistration" => "StudyRegistration",
      "text" => "Text",
      "workflow" => "Workflow",
      "other" => "Other"
    }.freeze

    # The schema-version segment (4.5 vs 4.7) varies across the authority
    # files, so it's left unanchored; only the trailing #fragment matters.
    DATACITE_URI = %r{\Ahttps?://datacite-metadata-schema\.readthedocs\.io/.*resourceTypeGeneral/#(?<fragment>[a-z]+)\z}

    # Human-curated fallback for a subtype whose own term has no direct
    # DataCite id (GENERAL_BY_FRAGMENT above), but whose *label* suggests a
    # reasonable DataCite type anyway -- keyed by a prefix of the term label
    # (e.g. "Physical Object" matches "Physical Object - Sculpture",
    # "Physical Object - Installation", ...; an exact label like "Working
    # paper" is just its own maximal prefix). The longest matching prefix
    # wins, so a specific entry can override a broader one.
    #
    # These are opinionated guesses, expected to need revisiting -- nothing
    # else in this file depends on the exact values, so edit freely. Terms
    # deliberately left unmapped (fall through to "Other" or the work's
    # CLASS_DEFAULT_GENERAL below) because no DataCite type fits well:
    # artefact_type.yml's bare "Visual Media", "CartographicMaterial", the
    # whole "Design" family, and artefact_type's "Exhibition" (the realised
    # output, not the dated occasion -- see event_type.yml's own "Exhibition",
    # which falls through to PortfolioEvent's "Event" default instead).
    FALLBACK_GENERAL_BY_PREFIX = {
      # artefact_type.yml
      "Physical Object" => "PhysicalObject",
      "Visual Media - StillImage" => "Image",
      "Visual Media - MovingImage" => "Audiovisual",
      "Sound" => "Sound",
      "InteractiveResource" => "InteractiveResource",
      "Dataset" => "Dataset",
      # literature_type.yml
      "Thesis" => "Dissertation",
      "Bachelor thesis" => "Dissertation",
      "Doctoral thesis" => "Dissertation",
      "Master thesis" => "Dissertation",
      "Working paper" => "Preprint",
      "Technical report" => "Report",
      "Research report" => "Report",
      "Annual / progress report" => "Report",
      "Policy report" => "Report",
      "Policy briefing" => "Report",
      "Conference output" => "ConferencePaper",
      "Conference paper not in proceedings" => "ConferencePaper",
      "Data management plan" => "OutputManagementPlan"
    }.freeze

    # A default DataCite resourceTypeGeneral for a work class as a whole,
    # used when neither GENERAL_BY_FRAGMENT nor FALLBACK_GENERAL_BY_PREFIX
    # matched -- reasonable for event/literature/collection works, which are
    # each fundamentally one kind of thing. No default for PortfolioArtefact:
    # it's too heterogeneous (physical/visual/sound/interactive/dataset), so
    # it relies on FALLBACK_GENERAL_BY_PREFIX and otherwise "Other".
    CLASS_DEFAULT_GENERAL = {
      "PortfolioEvent" => "Event",
      "PortfolioLiterature" => "Text",
      "PortfolioItemCollection" => "Collection"
    }.freeze

    module_function

    # @param work [#item_subtype]
    # @return [String] a DataCite resourceTypeGeneral value; "Other" if
    #   nothing below resolves one
    def general_for(work)
      value = work.try(:item_subtype)
      value = value.first if value.is_a?(Array)

      general_for_subtype_id(value) ||
        general_for_subtype_label(value) ||
        CLASS_DEFAULT_GENERAL[work.class.name] ||
        "Other"
    end

    # @param id [String, nil] a subtype authority term id (the value stored
    #   on the work, e.g. "https://.../resourceTypeGeneral/#physicalobject")
    # @return [String, nil]
    def general_for_subtype_id(id)
      match = DATACITE_URI.match(id.to_s)
      return nil unless match

      GENERAL_BY_FRAGMENT[match[:fragment]]
    end

    # @param id [String, nil]
    # @return [String, nil] a FALLBACK_GENERAL_BY_PREFIX match on the
    #   subtype's human label (resolved via Enact::ItemSubtypeLabels, which
    #   already looks up a term's label across all four authorities), or nil
    #   if the id doesn't resolve to a known term or no prefix matches
    def general_for_subtype_label(id)
      return nil if id.blank?

      label = Enact::ItemSubtypeLabels.label_for(id)
      return nil if label == id

      prefix = FALLBACK_GENERAL_BY_PREFIX.keys.select { |p| label.start_with?(p) }.max_by(&:length)
      prefix && FALLBACK_GENERAL_BY_PREFIX[prefix]
    end
  end
end
