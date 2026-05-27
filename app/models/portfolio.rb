# frozen_string_literal: true

# Enact Portfolio - parent practice-research work that aggregates one or more
# PortfolioItem children. Registered with Hyrax as `:portfolio` so URLs read
# `/concern/portfolios/...` for depositors.
#
# All attributes (scalar and compound) are declared in
# `config/metadata/portfolio.yaml`. Compound attributes use `type: hash`;
# each persisted entry is a JSONB hash on the parent. See the YAML header
# for sub-field shapes.
class Portfolio < Hyrax::Work
  if Hyrax.config.work_include_metadata?
    include Hyrax::Schema(:core_metadata)
    include Hyrax::Schema(:portfolio)
  end

  include Hyrax::ArResource
  include Hyrax::NestedWorks
  prepend EnactCompoundNormalization

  # HykuIndexing hardcodes `object.creator&.first`. Enact has no `creator`
  # field (contributors with typed roles cover that role per CLAUDE.md), so
  # we expose a nil stub purely to keep the shared indexer happy.
  def creator; end
end

# Backward-compatibility alias so previously-persisted records (with
# `internal_resource: "PortfolioResource"`) still resolve to the renamed class.
PortfolioResource = Portfolio unless defined?(PortfolioResource)
