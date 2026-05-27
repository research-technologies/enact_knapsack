# frozen_string_literal: true

# Enact-specific catalog config: surface the PR Voices type discriminator
# in the facet sidebar and on each search result row, so depositors and
# pathfinders can drill into the schema's primary pivot.
#
# Scope per CoSector demo (2026-05-27): just `portfolio_item_type` and
# `item_subtype`. Broader facets (research_group / ref_unit_of_assessment /
# contributor / license) wait for client direction.
module CatalogControllerDecorator
  # `add_*_field` raises on duplicate keys, and `to_prepare` re-runs this
  # decorator on every request in dev, so guard with `unless present?`.
  ENACT_FACETS = {
    'portfolio_item_type_sim' => { label: 'Portfolio Item Type', limit: 5 },
    'item_subtype_sim' => { label: 'Subtype',             limit: 10 }
  }.freeze

  ENACT_INDEX_FIELDS = {
    'portfolio_item_type_tesim' => { label: 'Type', link_to_facet: 'portfolio_item_type_sim' },
    'item_subtype_tesim' => { label: 'Subtype', link_to_facet: 'item_subtype_sim' }
  }.freeze

  def self.prepended(base)
    base.configure_blacklight do |config|
      ENACT_FACETS.each { |key, opts| config.add_facet_field(key, **opts) if config.facet_fields[key].blank? }
      ENACT_INDEX_FIELDS.each do |key, opts|
        config.add_index_field(key, **opts, if: :render_in_tenant?) if config.index_fields[key].blank?
      end
      # Hyku's CatalogController calls `add_facet_fields_to_solr_request!`
      # before our decorator runs, so newly added facet fields aren't included
      # in the Solr facet.field query unless we re-call it here.
      config.add_facet_fields_to_solr_request!
    end
  end
end

CatalogController.prepend(CatalogControllerDecorator)
