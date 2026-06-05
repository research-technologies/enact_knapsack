# frozen_string_literal: true

# Compound subfields are indexed by Hyrax from the M3 profile. The knapsack
# indexer keeps only the Hyku wiring HykuIndexing supplies.
class PortfolioItemIndexer < Hyrax::ValkyrieWorkIndexer
  include HykuIndexing

  if Hyrax.config.work_include_metadata?
    include Hyrax::Indexer(:core_metadata)
    include Hyrax::Indexer(:portfolio_item)
  end
  check_if_flexible(PortfolioItem)
end

PortfolioItemResourceIndexer = PortfolioItemIndexer unless defined?(PortfolioItemResourceIndexer)
