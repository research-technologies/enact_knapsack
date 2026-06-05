# frozen_string_literal: true

# Compound subfields are indexed by Hyrax from the M3 profile.
class PortfolioArtefactIndexer < Hyrax::ValkyrieWorkIndexer
  include HykuIndexing

  if Hyrax.config.work_include_metadata?
    include Hyrax::Indexer(:core_metadata)
    include Hyrax::Indexer(:portfolio_artefact)
  end
  check_if_flexible(PortfolioArtefact)
end

PortfolioArtefactResourceIndexer = PortfolioArtefactIndexer unless defined?(PortfolioArtefactResourceIndexer)
