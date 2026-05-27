# frozen_string_literal: true

# Flatten compound hash entries into searchable Solr fields. See
# PortfolioIndexer for the shared pattern; this indexer adds `geo_place_name_*`
# for the Artefact/Event geo_locations compound.
class PortfolioItemIndexer < Hyrax::ValkyrieWorkIndexer
  include EnactCompoundLabelHelpers
  include HykuIndexing

  if Hyrax.config.work_include_metadata?
    include Hyrax::Indexer(:core_metadata)
    include Hyrax::Indexer(:portfolio_item)
  end
  check_if_flexible(PortfolioItem)

  COMPOUND_INDEX_MAP = PortfolioIndexer::COMPOUND_INDEX_MAP.merge(
    geo_locations: %i[geo_place_name geo_place_name]
  ).freeze

  def to_solr
    super.tap do |doc|
      COMPOUND_INDEX_MAP.each { |attr, (key, method)| write_compound_labels(doc, attr, key, method) }
    end
  end
end

PortfolioItemResourceIndexer = PortfolioItemIndexer unless defined?(PortfolioItemResourceIndexer)
