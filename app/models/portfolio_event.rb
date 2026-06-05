# frozen_string_literal: true

# Enact PortfolioEvent - prototype work type, one of four typed siblings
# under a Portfolio. Carries geo_locations alongside PortfolioArtefact.
# All attributes are declared in `config/metadata/portfolio_event.yaml`.
class PortfolioEvent < Hyrax::Work
  if Hyrax.config.work_include_metadata?
    include Hyrax::Schema(:core_metadata)
    include Hyrax::Schema(:portfolio_event)
    include Hyrax::Schema(:bulkrax_metadata)
  end

  include Hyrax::ArResource
  include Hyrax::NestedWorks

  def self.human_readable_type
    'Event'
  end

  def human_readable_type
    self.class.human_readable_type
  end

  def creator; end
end

PortfolioEventResource = PortfolioEvent unless defined?(PortfolioEventResource)
