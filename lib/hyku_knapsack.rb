# frozen_string_literal: true

# Respect Hyku's default: HYRAX_FLEXIBLE is off unless set by the app (e.g. .env, docker-compose).
# Do not set ENV['HYRAX_FLEXIBLE'] here so downstream apps control it.

require "hyku_knapsack/version"
require "hyku_knapsack/engine"
require "hyku_knapsack/active_job_user"
require "hyku_knapsack/current"
require "hyku_knapsack/user_jobs"

# Disable include_metadata only when flexible mode is explicitly enabled.
ENV['HYRAX_DISABLE_INCLUDE_METADATA'] = 'true' if ENV['HYRAX_FLEXIBLE'] == 'true'

module HykuKnapsack
  # Your code goes here...
end
