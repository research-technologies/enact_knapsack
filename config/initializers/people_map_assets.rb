# frozen_string_literal: true

# Vendored Cytoscape.js (knapsack-local, app/assets/javascripts/cytoscape.js,
# shared with the relationship map) powers the standalone "research network"
# people-map page, alongside its page-specific CSS and JS
# (app/assets/{stylesheets,javascripts}/enact/people_map.*). The page renders
# with `layout: false`, so it pulls these in with its own
# `stylesheet_link_tag`/`javascript_include_tag`; precompiling them here keeps
# that working under a production/staging build where assets are not served on
# the fly. (cytoscape.js is already precompiled in relationship_map_assets.rb;
# listing it again is a harmless no-op.)
if Rails.application.config.respond_to?(:assets)
  Rails.application.config.assets.precompile += %w[
    enact/people_map.js
    enact/people_map.css
  ]
end
