# frozen_string_literal: true

# Enact PortfolioItemResource - a single typed output within a Portfolio. The
# `portfolio_item_type` discriminator selects Artefact / Event / Literature /
# Collection; `item_subtype` is filtered against the chosen type via Stimulus.
#
# All attributes (scalar and compound) are declared in
# config/metadata/portfolio_item_resource.yaml. Compound attributes use
# `type: hash`; each persisted entry is a JSONB hash on the parent. See the
# YAML header for sub-field shapes.
class PortfolioItemResource < Hyrax::Work
  if Hyrax.config.work_include_metadata?
    include Hyrax::Schema(:core_metadata)
    include Hyrax::Schema(:portfolio_item_resource)
  end

  include Hyrax::ArResource
  include Hyrax::NestedWorks
end
