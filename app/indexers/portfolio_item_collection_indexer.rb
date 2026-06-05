# frozen_string_literal: true

# Compound subfields are indexed by Hyrax from the M3 profile.
class PortfolioItemCollectionIndexer < Hyrax::ValkyrieWorkIndexer
  include HykuIndexing

  if Hyrax.config.work_include_metadata?
    include Hyrax::Indexer(:core_metadata)
    include Hyrax::Indexer(:portfolio_item_collection)
  end
  check_if_flexible(PortfolioItemCollection)
end

PortfolioItemCollectionResourceIndexer = PortfolioItemCollectionIndexer unless defined?(PortfolioItemCollectionResourceIndexer)
