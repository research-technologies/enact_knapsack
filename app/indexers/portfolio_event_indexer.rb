# frozen_string_literal: true

# Compound subfields are indexed by Hyrax from the M3 profile.
class PortfolioEventIndexer < Hyrax::ValkyrieWorkIndexer
  include HykuIndexing

  if Hyrax.config.work_include_metadata?
    include Hyrax::Indexer(:core_metadata)
    include Hyrax::Indexer(:portfolio_event)
  end
  check_if_flexible(PortfolioEvent)
end

PortfolioEventResourceIndexer = PortfolioEventIndexer unless defined?(PortfolioEventResourceIndexer)
