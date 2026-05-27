# frozen_string_literal: true

# Enact-specific catalog config: surface the PR Voices type discriminator
# in the facet sidebar and on each search result row, so depositors and
# pathfinders can drill into the schema's primary pivot.
#
# Scope per CoSector demo (2026-05-27): just `portfolio_item_type` and
# `item_subtype`. Broader facets (research_group / ref_unit_of_assessment /
# contributor / license) wait for client direction.
module CatalogControllerDecorator
  def self.prepended(base)
    base.configure_blacklight do |config|
      # `add_*_field` raises on duplicate keys, and `to_prepare` re-runs this
      # decorator on every request in dev, so guard with `unless present?`.
      unless config.facet_fields['portfolio_item_type_sim'].present?
        config.add_facet_field 'portfolio_item_type_sim', label: 'Portfolio Item Type', limit: 5
      end
      unless config.facet_fields['item_subtype_sim'].present?
        config.add_facet_field 'item_subtype_sim', label: 'Subtype', limit: 10
      end

      unless config.index_fields['portfolio_item_type_tesim'].present?
        config.add_index_field 'portfolio_item_type_tesim',
                               label: 'Type',
                               link_to_facet: 'portfolio_item_type_sim',
                               if: :render_in_tenant?
      end
      unless config.index_fields['item_subtype_tesim'].present?
        config.add_index_field 'item_subtype_tesim',
                               label: 'Subtype',
                               link_to_facet: 'item_subtype_sim',
                               if: :render_in_tenant?
      end
    end
  end
end

CatalogController.prepend(CatalogControllerDecorator)
