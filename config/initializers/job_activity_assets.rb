# frozen_string_literal: true

if Rails.application.config.respond_to?(:assets)
  Rails.application.config.assets.precompile += %w[
    enact/job_activity.js
    enact/job_activity.css
  ]
end
