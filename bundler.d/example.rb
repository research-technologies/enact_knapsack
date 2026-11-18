# frozen_string_literal: true
# see https://github.com/kbrock/bundler-inject/tree/gem_path

# specify one or more ruby files in this directory to be injected into bundler
# you can use `gem` to add new gems, `override_gem` to change an existing gem
# or `ensure_gem` to make sure a gem is there w/o worrying about if it is an
# override or not

# OVERRIDE Bulkrax v9.5.1 Gemfile bulkrax version constraint: pins ahead to
#   v9.5.2. Remove once hyrax-webapp vendors a Hyku release at or past v7.2.2.
override_gem "bulkrax", "~> 9.5.2"
