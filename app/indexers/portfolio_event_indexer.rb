# frozen_string_literal: true

# Indexer for PortfolioEvent. Same shape as PortfolioArtefactIndexer
# (both include the geo_locations compound).
class PortfolioEventIndexer < Hyrax::ValkyrieWorkIndexer
  include EnactCompoundLabelHelpers
  include HykuIndexing

  if Hyrax.config.work_include_metadata?
    include Hyrax::Indexer(:core_metadata)
    include Hyrax::Indexer(:portfolio_event)
  end
  check_if_flexible(PortfolioEvent)

  COMPOUND_INDEX_MAP = PortfolioIndexer::COMPOUND_INDEX_MAP.merge(
    geo_locations: %i[geo_place_name geo_place_name]
  ).freeze

  def to_solr
    super.tap do |doc|
      COMPOUND_INDEX_MAP.each { |attr, (key, method)| write_compound_labels(doc, attr, key, method) }
    end
  end
end

PortfolioEventResourceIndexer = PortfolioEventIndexer unless defined?(PortfolioEventResourceIndexer)
