# frozen_string_literal: true

# Form for PortfolioEvent. Compound attributes live in
# config/metadata_profiles/m3_profile.yaml and render via Hyrax's compound
# foundation.
class PortfolioEventForm < Hyrax::Forms::ResourceForm(PortfolioEvent)
  if Hyrax.config.work_include_metadata?
    include Hyrax::FormFields(:portfolio_event)
    include Hyrax::FormFields(:bulkrax_metadata)
  end
  check_if_flexible(PortfolioEvent)
end

PortfolioEventResourceForm = PortfolioEventForm unless defined?(PortfolioEventResourceForm)
