# frozen_string_literal: true

# Scalar and compound fields are indexed by Hyrax from the M3 profile (each
# subfield's `indexing:` directive). The knapsack indexer keeps only the Hyku
# wiring HykuIndexing supplies (valkyrie_bsi, member_ids_ssim, generic_type_sim,
# all_text_tsimv, ...).
class PortfolioIndexer < Hyrax::ValkyrieWorkIndexer
  include HykuIndexing

  if Hyrax.config.work_include_metadata?
    include Hyrax::Indexer(:core_metadata)
    include Hyrax::Indexer(:portfolio)
  end
  check_if_flexible(Portfolio)
end

PortfolioResourceIndexer = PortfolioIndexer unless defined?(PortfolioResourceIndexer)
