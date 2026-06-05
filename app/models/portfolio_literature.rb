# frozen_string_literal: true

# Enact PortfolioLiterature - prototype work type, one of four typed siblings
# under a Portfolio. Carries place_of_publication; does not carry geo_locations.
# All attributes are declared in `config/metadata/portfolio_literature.yaml`.
class PortfolioLiterature < Hyrax::Work
  if Hyrax.config.work_include_metadata?
    include Hyrax::Schema(:core_metadata)
    include Hyrax::Schema(:portfolio_literature)
    include Hyrax::Schema(:bulkrax_metadata)
  end

  include Hyrax::ArResource
  include Hyrax::NestedWorks

  def self.human_readable_type
    'Literature'
  end

  def human_readable_type
    self.class.human_readable_type
  end

  def creator; end
end

PortfolioLiteratureResource = PortfolioLiterature unless defined?(PortfolioLiteratureResource)
