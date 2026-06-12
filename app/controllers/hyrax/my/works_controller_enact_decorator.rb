# frozen_string_literal: true

# OVERRIDE Hyrax 5.2 / Hyku: add a "Work Type" dropdown to the dashboard Works
# filter row (next to Visibility / Status / Admin Set).
#
# The filter row renders every facet configured on this controller as a
# dropdown (hyrax/my/works/_facets.html.erb via
# Hyrax::DropdownFacetFieldComponent), so declaring the facet is all it takes.
# The facet declaration and the human-name label helper live in
# EnactWorkTypeFacet, shared with the catalog search page.
#
# Named *EnactDecorator because Hyku already ships a
# Hyrax::My::WorksControllerDecorator (sort fields) and this file must define
# its own Zeitwerk-matching constant.
module Hyrax
  module My
    module WorksControllerEnactDecorator
    end
  end
end

EnactWorkTypeFacet.add_facet_to(Hyrax::My::WorksController)
