# frozen_string_literal: true

# Enact PortfolioResource - parent practice-research work that aggregates one or
# more PortfolioItemResource children.
#
# All attributes (scalar and compound) are declared in
# config/metadata/portfolio_resource.yaml. Compound attributes use `type: hash`;
# each persisted entry is a JSONB hash on the parent. See the YAML header for
# sub-field shapes.
class PortfolioResource < Hyrax::Work
  if Hyrax.config.work_include_metadata?
    include Hyrax::Schema(:core_metadata)
    include Hyrax::Schema(:portfolio_resource)
  end

  include Hyrax::ArResource
  include Hyrax::NestedWorks
end
