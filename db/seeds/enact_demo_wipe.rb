# frozen_string_literal: true

# Wipe every Portfolio + PortfolioItem (and their FileSets/Solr docs) for the
# dev tenant. Pair with db/seeds/enact_demo.rb to start from a clean slate.
#
# Run inside the web container:
#
#   docker exec -i enact_knapsack-web-1 sh -c \
#     'cd /app/samvera/hyrax-webapp && bundle exec rails runner /app/samvera/db/seeds/enact_demo_wipe.rb'

AccountElevator.switch!(ENV.fetch('ENACT_DEMO_TENANT', 'dev-enact-knapsack.localhost.direct'))

[Portfolio, PortfolioItem].each do |klass|
  records = Hyrax.query_service.find_all_of_model(model: klass).to_a
  puts "#{klass.name}: deleting #{records.size}"
  records.each do |r|
    Hyrax.persister.delete(resource: r)
  rescue StandardError => e
    puts "  delete #{r.id} failed: #{e.class}: #{e.message}"
  end
end

# Clean any orphaned Solr docs (legacy *Resource has_model_ssim values + the
# canonical Portfolio/PortfolioItem entries we just removed).
q = 'has_model_ssim:Portfolio OR has_model_ssim:PortfolioItem ' \
    'OR has_model_ssim:PortfolioResource OR has_model_ssim:PortfolioItemResource'
Hyrax::SolrService.delete_by_query(q)
Hyrax::SolrService.commit
puts 'done'
