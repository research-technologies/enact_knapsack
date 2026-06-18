# frozen_string_literal: true

# Vendored Cytoscape.js (knapsack-local, app/assets/javascripts/cytoscape.js)
# powers the standalone relationship-map page, alongside the page-specific CSS
# and JS extracted from the view (app/assets/{stylesheets,javascripts}/enact/
# relationship_map.*). The map view renders with `layout: false`, so it pulls
# these in with its own `stylesheet_link_tag`/`javascript_include_tag`;
# precompiling them here keeps that working under a production/staging build
# where the assets are not served on the fly.
if Rails.application.config.respond_to?(:assets)
  Rails.application.config.assets.precompile += %w[
    cytoscape.js
    enact/relationship_map.js
    enact/relationship_map.css
  ]
end
