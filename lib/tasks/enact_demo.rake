# frozen_string_literal: true

# Enact demo data pipeline.
#
# Seeds the demo tenant with four practice-research Portfolios + sixteen typed
# PortfolioItem children (Artefact / Event / Literature / Collection), each
# with a themed placeholder image, full compound metadata, public visibility,
# and Universal Viewer wired at the Portfolio level.
#
# Tenant defaults to demo.enact-knapsack-staging.enacthyku.com. Override with
# ENACT_DEMO_TENANT. Files dir defaults to /tmp/enact_seed.
#
# Usage (from /app/samvera/hyrax-webapp inside the web container):
#
#   bundle exec rake enact:demo:all                # full pipeline
#   bundle exec rake enact:demo:images             # placeholder PNGs only
#   bundle exec rake enact:demo:wipe               # wipe demo tenant only
#   bundle exec rake enact:demo:seed               # multi-portfolio seed only
#   bundle exec rake enact:demo:seed_single        # single-portfolio reference seed
#
# Seed source files live in db/seeds/ at the knapsack root.

namespace :enact do
  namespace :demo do
    def seeds_dir
      HykuKnapsack::Engine.root.join('db', 'seeds')
    end

    desc 'Generate themed placeholder PNGs in $ENACT_DEMO_FILES_DIR (default /tmp/enact_seed)'
    task images: :environment do
      sh "sh #{seeds_dir.join('generate_demo_images.sh')}"
    end

    desc 'Wipe Portfolio / PortfolioItem records in $ENACT_DEMO_TENANT'
    task wipe: :environment do
      load seeds_dir.join('enact_demo_wipe.rb').to_s
    end

    desc 'Seed 4 portfolios + 16 typed items + files into $ENACT_DEMO_TENANT'
    task seed: :environment do
      load seeds_dir.join('enact_demo_multi.rb').to_s
    end

    desc 'Seed a single reference portfolio (dev convenience, 1 portfolio + 4 children)'
    task seed_single: :environment do
      load seeds_dir.join('enact_demo.rb').to_s
    end

    desc 'Full demo pipeline: images + wipe + seed'
    task all: %i[images wipe seed]
  end
end
