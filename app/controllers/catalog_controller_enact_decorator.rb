# frozen_string_literal: true

# OVERRIDE Hyku: add a "Work Type" facet to the catalog search sidebar, so
# search results can be narrowed to Portfolios vs the item types. The facet
# declaration and the human-name label helper live in EnactWorkTypeFacet,
# shared with the dashboard Works page.
module CatalogControllerEnactDecorator
end

EnactWorkTypeFacet.add_facet_to(CatalogController, limit: 5)
