# frozen_string_literal: true

# CSS and JS for the enactMapModal iframe modal (app/assets/{stylesheets,
# javascripts}/enact/map_modal.*). These assets are included from the
# enact/shared/_map_modal partial, which renders inside the normal Hyrax
# application layout rather than a standalone layout:false page, so they are
# not pulled in automatically by the application manifest. Precompiling them
# here ensures the tags resolve in production/staging builds.
if Rails.application.config.respond_to?(:assets)
  Rails.application.config.assets.precompile += %w[
    enact/map_modal.js
    enact/map_modal.css
  ]
end
