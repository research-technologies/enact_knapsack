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
    # bulkrax_identifier round-trips Bulkrax's `source_identifier` so
    # `factory.run!` can find the record back after creation; without it
    # every CSV row reports "Record invalid" even when the work persists.
    include Hyrax::Schema(:bulkrax_metadata)
  end

  include Hyrax::ArResource
  include Hyrax::NestedWorks

  # HykuIndexing hardcodes `object.creator&.first`. Enact has no `creator`
  # field (contributors with typed roles cover that role per CLAUDE.md), so
  # we expose a nil stub purely to keep the shared indexer happy.
  def creator; end
end

# Backward-compatibility alias so previously-persisted records (with
# `internal_resource: "PortfolioResource"`) still resolve to the renamed class.
PortfolioResource = Portfolio unless defined?(PortfolioResource)
