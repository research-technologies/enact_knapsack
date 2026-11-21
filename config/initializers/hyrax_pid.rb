# frozen_string_literal: true

# Configures hyrax-pid's DataCite adapter for this knapsack.
#
# Credentials aren't set here: tenant admins enter them at
# /pid/admin/services. The "Mint DOI" button (rendered from the
# `/hyrax/base/_show_actions` override) shows once DataCite is configured there
# and the tenant's "mint_doi" feature is on at /admin/features.
#
# No real DataCite account exists for this environment yet, so this swaps in a
# fake client (HykuKnapsack::FakeDataCiteClient) that fabricates DataCite-shaped
# responses in-process, with no network call; any values entered on the
# settings page will do. Delete the `config.data_cite.client` line to mint for
# real, which falls the minter back to its default Net::HTTP client.
Rails.application.config.to_prepare do
  Hyrax::Pid.configure do |config|
    config.data_cite.client = HykuKnapsack::FakeDataCiteClient.new

    # Maps DataCite's minimum-required fields
    # (https://datacite-metadata-schema.readthedocs.io/en/4.7/properties/overview/)
    # onto this knapsack's M3 profile (config/metadata_profiles/m3_profile.yaml).
    # Symbols are read as a method on the work; anything callable is called
    # with the work; anything else is used as a literal constant. See
    # Hyrax::Pid::DataCite::MetadataMapper.
    #
    # Enact has no flat `creator`/`publisher` field to point at: both are
    # credits on the work's `contributors` compound, tagged by role (e.g.
    # "author", "publisher") against a linked Enact::Contributor profile
    # (name, ORCID, affiliations, ...) -- see Enact::DataCiteMetadata, which
    # does the role filtering and profile lookup.
    config.data_cite.field_mapping = {
      title: :title,
      creator: ->(work) { Enact::DataCiteMetadata.creators_for(work) },
      publisher: ->(work) { Enact::DataCiteMetadata.publisher_for(work) },
      # Prefers a "Published"-typed entry on the work's `dates` compound
      # over `date_created` (which is when the record was created, not
      # necessarily when the work itself was published) -- see
      # Enact::DataCitePublicationYear.
      publication_year: ->(work) { Enact::DataCitePublicationYear.year_for(work) },
      # item_subtype's own authority terms (config/authorities/
      # {artefact,literature,collection,event}_type.yml) already reference
      # the DataCite schema directly for some terms -- Enact::DataCiteResourceType
      # reuses that reference instead of defaulting every work to "Other".
      resource_type_general: ->(work) { Enact::DataCiteResourceType.general_for(work) },
      # Optional: the work's `relationships`
      # compound maps onto DataCite's relatedItem, via relationship_types.yml's
      # own `datacite:` key per term -- see Enact::DataCiteRelatedItems.
      related_items: ->(work) { Enact::DataCiteRelatedItems.related_items_for(work) }
    }
  end
end
