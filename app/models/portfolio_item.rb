# frozen_string_literal: true

# Enact PortfolioItem - a single typed output within a Portfolio. The
# `portfolio_item_type` discriminator selects Artefact / Event / Literature /
# Collection; `item_subtype` is filtered against the chosen type via Stimulus.
#
# All attributes (scalar and compound) are declared in
# `config/metadata/portfolio_item.yaml`. Compound attributes use `type: hash`;
# each persisted entry is a JSONB hash on the parent. See the YAML header for
# sub-field shapes.
class PortfolioItem < Hyrax::Work
  if Hyrax.config.work_include_metadata?
    include Hyrax::Schema(:core_metadata)
    include Hyrax::Schema(:portfolio_item)
    # See Portfolio for why bulkrax_identifier needs to be on the resource.
    include Hyrax::Schema(:bulkrax_metadata)
  end

  include Hyrax::ArResource
  include Hyrax::NestedWorks

  # HykuIndexing hardcodes `object.creator&.first`. Enact has no `creator`
  # field (contributors with typed roles cover that role per CLAUDE.md), so
  # we expose a nil stub purely to keep the shared indexer happy.
  def creator; end
end

PortfolioItemResource = PortfolioItem unless defined?(PortfolioItemResource)
