# frozen_string_literal: true

# Vendored Cytoscape.js (knapsack-local, app/assets/javascripts/cytoscape.js)
# powers the standalone relationship-map page. The map view renders with
# `layout: false`, so it pulls the library in with its own
# `javascript_include_tag 'cytoscape'`; precompiling it here keeps that working
# under a production/staging build where the asset is not served on the fly.
Rails.application.config.assets.precompile += %w[cytoscape.js] if Rails.application.config.respond_to?(:assets)
