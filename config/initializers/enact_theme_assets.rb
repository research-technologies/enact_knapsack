# frozen_string_literal: true
#
# Register the Enact theme assets for precompilation. The dev-staging Docker
# build runs Rails in production mode (assets precompile + serve digested
# manifests), so any asset referenced by `stylesheet_link_tag 'themes/enact'`
# must be declared here or Sprockets raises AssetNotPrecompiledError.
#
# Loaded by HykuKnapsack::Engine after Hyku's own assets.rb, so this appends
# to the existing precompile list rather than replacing it.

Rails.application.config.assets.precompile += %w[
  themes/enact.css
  themes/enact_show.css
  themes/enact/enact.jpg
  themes/enact_show/enact_show.jpg
]
