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

    # PortfolioResource scalars (only those not already declared by Hyrax).
    attribute :context_statement, array_type, 'context_statement_tesim'
    attribute :date_made_public, array_type, 'date_made_public_tesim'
    attribute :portfolio_date_range, array_type, 'portfolio_date_range_tesim'
    attribute :raid_identifier, array_type, 'raid_identifier_ssi'
    attribute :research_group, array_type, 'research_group_tesim'
    attribute :metadata_rights_statement, array_type, 'metadata_rights_statement_tesim'
    attribute :file_access_level, array_type, 'file_access_level_tesim'
    attribute :ref_unit_of_assessment, array_type, 'ref_unit_of_assessment_tesim'

    # PortfolioItemResource scalars.
    attribute :portfolio_item_type, array_type, 'portfolio_item_type_tesim'
    attribute :item_subtype, array_type, 'item_subtype_tesim'
    attribute :media_type, array_type, 'media_type_tesim'
    attribute :related_item, array_type, 'related_item_tesim'
    attribute :place_of_publication, array_type, 'place_of_publication_tesim'
    attribute :extent, array_type, 'extent_tesim'
    attribute :extent_type, array_type, 'extent_type_tesim'
    attribute :collection_order, array_type, 'collection_order_tesim'

    # Flattened *_label / *_value / *_name fields written by the Enact indexers
    # for each compound attribute. The show-page partial calls these directly
    # via `attribute_to_html`.
    attribute :contributor_label, array_type, 'contributor_label_tesim'
    attribute :identifier_value, array_type, 'identifier_value_tesim'
    attribute :funder_label, array_type, 'funder_label_tesim'
    attribute :organisational_unit_label, array_type, 'organisational_unit_label_tesim'
    attribute :license_label, array_type, 'license_label_tesim'
    attribute :geo_place_name, array_type, 'geo_place_name_tesim'
  end
end

SolrDocument.include(SolrDocumentDecorator)
