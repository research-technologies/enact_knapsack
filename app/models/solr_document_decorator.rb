# frozen_string_literal: true

# Adds Enact-specific attribute declarations to SolrDocument so the show-page
# presenters' `respond_to?(:foo)` checks pass for our schema fields. Without
# these, Hyrax::PresentsAttributes#attribute_to_html silently drops every Enact
# field from the show page.
#
# `attribute name, type, solr_field` is provided by
# Hyrax::SolrDocument::Metadata which is already mixed into SolrDocument
# (hyrax-webapp). We just keep adding entries the same way.
#
# Defined as a module (rather than a bare `SolrDocument.class_eval`) so the
# file passes Zeitwerk's eager-load constant-name check in production. The
# knapsack engine's `*_decorator*.rb` glob includes us at to_prepare time.
module SolrDocumentDecorator
  extend ActiveSupport::Concern

  included do
    array_type = Hyrax::SolrDocument::Metadata::Solr::Array

    # Portfolio scalars (only those not already declared by Hyrax).
    attribute :context_statement, array_type, 'context_statement_tesim'
    attribute :date_made_public, array_type, 'date_made_public_tesim'
    attribute :date_range_of_outputs, array_type, 'date_range_of_outputs_tesim'
    attribute :portfolio_identifier, array_type, 'portfolio_identifier_ssi'
    attribute :research_group, array_type, 'research_group_tesim'
    # `rights_statement` is already declared by Hyrax SolrDocument::Metadata
    # (basic_metadata field). PR Voices uses the same name on Portfolio with
    # semantics "rights to the portfolio record".
    attribute :file_access_level, array_type, 'file_access_level_tesim'
    attribute :ref_unit_of_assessment, array_type, 'ref_unit_of_assessment_tesim'

    # Portfolio child-work scalars (shared by Artefact / Event / Literature /
    # ItemCollection).
    attribute :item_subtype, array_type, 'item_subtype_tesim'
    attribute :media_type, array_type, 'media_type_tesim'
    attribute :related_item, array_type, 'related_item_tesim'
    attribute :place_of_publication, array_type, 'place_of_publication_tesim'
    attribute :extent, array_type, 'extent_tesim'
    attribute :extent_type, array_type, 'extent_type_tesim'
    attribute :collection_order, array_type, 'collection_order_tesim'

    # Compound (`type: hash`) readers. Hyrax::SolrDocument::Metadata hard-codes
    # compound_attribute declarations only for its four sample compounds
    # (agents/identifiers/compound_rights/relationships). The Enact compounds
    # need their own readers so the compound foundation renderer can read each
    # `<name>_json_ss` Solr field back into an Array<Hash> for the show page.
    compound_attribute :titles
    compound_attribute :dates
    compound_attribute :contributors
    compound_attribute :identifiers
    compound_attribute :funding_references
    compound_attribute :organisational_units
    compound_attribute :licenses
    compound_attribute :geo_locations
  end
end

SolrDocument.include(SolrDocumentDecorator)
