# frozen_string_literal: true

# bundler-inject loads this into hyrax-webapp/Gemfile, the Gemfile the app
# actually boots from.
#
# `branch:` is required for Bundler's local override: docker-compose.override.yml
# mounts a local checkout and sets BUNDLE_LOCAL__HYRAX_PID to use it instead.
gem 'hyrax-pid', github: "research-technologies/hyrax-pid", branch: "main"
