# frozen_string_literal: true

module Enact
  # Supplies hyrax-pid's DataCite :related_items field_mapping value (see
  # config/initializers/hyrax_pid.rb) from a work's `relationships` compound.
  # relatedItem is optional in DataCite's schema, unlike the fields
  # Hyrax::Pid::DataCite::MetadataMapper requires -- an edge that can't be
  # mapped meaningfully is just skipped, not a minting failure.
  #
  # config/authorities/relationship_types.yml already carries a `datacite:`
  # key per term -- a straightforward map to DataCite's relationType
  # vocabulary (mirroring contributor_roles.yml's `datacite:` key for
  # contributorType) -- read via the existing Enact::RelationshipTypesService,
  # same as Enact::WorkContributors/Enact::ContributorGraph reuse
  # Enact::ContributorRolesService rather than re-deriving anything.
  module DataCiteRelatedItems
    # Relationship_types.yml's own documented export policy for an edge with
    # no `datacite:` mapping (an Enact-local term, or a free-text "other"
    # edge): falls back to DataCite's own "Other", same escape hatch
    # DataCite's relationType/relatedItemType vocabularies already provide.
    DEFAULT_RELATION_TYPE = "Other"
    DEFAULT_RELATED_ITEM_TYPE = "Other"

    module_function

    # @param work [#relationships]
    # @return [Array<Hash>] a DataCite relatedItem object per relationships
    #   entry that has a usable type and target; [] if none
    def related_items_for(work)
      Array(work.try(:relationships)).filter_map { |entry| related_item_hash(entry) }
    end

    def related_item_hash(entry)
      relation_type = relation_type_for(entry)
      return nil if relation_type.blank?

      value = fetch(entry, :item).to_s
      return nil if value.blank?

      target = target_for(value)
      {relationType: relation_type, relatedItemType: related_item_type_for(target)}.merge(identifier_for(value, target))
    end

    # A controlled `type` maps through the authority (falling back to
    # "Other" for an Enact-local term with no `datacite:` key); an edge with
    # no controlled type but free-text `type_other` still gets "Other" (it's
    # a real, curator-described edge); an edge with neither has nothing to
    # export.
    def relation_type_for(entry)
      code = fetch(entry, :type)
      return Enact::RelationshipTypesService.datacite(code) || DEFAULT_RELATION_TYPE if code.present?

      DEFAULT_RELATION_TYPE if fetch(entry, :type_other).present?
    end

    # @return [:url, Object, nil] :url for an external link; the resolved
    #   target work for an internal id that still exists and is fetchable;
    #   nil for a dangling/inaccessible internal id
    def target_for(value)
      return :url if Hyrax::CompoundWorkResolver.url?(value)

      Hyrax.query_service.find_by(id: value)
    rescue Valkyrie::Persistence::ObjectNotFoundError, Hyrax::ObjectNotFoundError
      nil
    end

    # An internal target's own resourceTypeGeneral is a better guess than a
    # blanket "Other" -- reuses Enact::DataCiteResourceType rather than
    # re-deriving it, since we already have the target work in hand here.
    def related_item_type_for(target)
      return DEFAULT_RELATED_ITEM_TYPE if target.nil? || target == :url

      Enact::DataCiteResourceType.general_for(target)
    end

    # relatedItemIdentifier is optional (0-1) in DataCite's schema, so a
    # target with nothing usable (a dangling internal id, or an internal
    # work with no DOI of its own yet) just omits it rather than guessing.
    def identifier_for(value, target)
      return {relatedItemIdentifier: value, relatedItemIdentifierType: "URL"} if target == :url
      return {} if target.nil?

      doi = Array(target.try(:doi)).first
      doi.present? ? {relatedItemIdentifier: doi, relatedItemIdentifierType: "DOI"} : {}
    end

    # Compound entry keys read tolerantly (symbol or string) -- see
    # Enact::DataCiteMetadata for the same pattern on `contributors` entries.
    def fetch(entry, key)
      entry[key] || entry[key.to_s]
    end
  end
end
