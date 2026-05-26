# frozen_string_literal: true

class PortfolioResourceIndexer < Hyrax::ValkyrieWorkIndexer
  if Hyrax.config.work_include_metadata?
    include Hyrax::Indexer(:core_metadata)
    include Hyrax::Indexer(:portfolio_resource)
  end
  check_if_flexible(PortfolioResource)
end
