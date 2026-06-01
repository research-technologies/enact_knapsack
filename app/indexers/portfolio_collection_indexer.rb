# frozen_string_literal: true

# Indexer for PortfolioCollection. Uses PortfolioIndexer's base
# COMPOUND_INDEX_MAP (no geo_locations).
class PortfolioCollectionIndexer < Hyrax::ValkyrieWorkIndexer
  include EnactCompoundLabelHelpers
  include HykuIndexing

  if Hyrax.config.work_include_metadata?
    include Hyrax::Indexer(:core_metadata)
    include Hyrax::Indexer(:portfolio_collection)
  end
  check_if_flexible(PortfolioCollection)

  COMPOUND_INDEX_MAP = PortfolioIndexer::COMPOUND_INDEX_MAP

  def to_solr
    super.tap do |doc|
      COMPOUND_INDEX_MAP.each { |attr, (key, method)| write_compound_labels(doc, attr, key, method) }
    end
  end
end

PortfolioCollectionResourceIndexer = PortfolioCollectionIndexer unless defined?(PortfolioCollectionResourceIndexer)
