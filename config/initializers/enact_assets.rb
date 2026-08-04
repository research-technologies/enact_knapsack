# frozen_string_literal: true

# Sprockets targets for Enact's own page-level assets. Each is a separate entry point,
# pulled in by the view that needs it via stylesheet_link_tag / javascript_include_tag
# rather than through hyku_knapsack/application, so each has to be declared here.
#
# Add to this list as the theme grows beyond the work show page. job_activity_assets.rb,
# people_map_assets.rb and relationship_map_assets.rb each declare one feature's CSS and
# JS the same way, and are worth folding in here.
if Rails.application.config.respond_to?(:assets)
  Rails.application.config.assets.precompile += %w[
    enact/enact_home.css
    enact/enact_home.js
    enact/enact_show.css
    enact/enact_show.js
  ]
end
