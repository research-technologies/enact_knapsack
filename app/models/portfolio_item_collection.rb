# frozen_string_literal: true

# Enact PortfolioItemCollection - prototype work type, one of four typed siblings
# under a Portfolio. Carries extent / extent_type / collection_order scalars;
# does not carry geo_locations.
# All attributes are declared in `config/metadata/portfolio_item_collection.yaml`.
class PortfolioItemCollection < Hyrax::Work
  if Hyrax.config.work_include_metadata?
    include Hyrax::Schema(:core_metadata)
    include Hyrax::Schema(:portfolio_item_collection)
    include Hyrax::Schema(:bulkrax_metadata)
  end

  include Hyrax::ArResource
  include Hyrax::NestedWorks

  def self.human_readable_type
    'Collection'
  end

  def human_readable_type
    self.class.human_readable_type
  end

  def creator; end
end

PortfolioItemCollectionResource = PortfolioItemCollection unless defined?(PortfolioItemCollectionResource)
