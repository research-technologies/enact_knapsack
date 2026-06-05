# frozen_string_literal: true

# Form for PortfolioLiterature. Compound attributes live in
# config/metadata_profiles/m3_profile.yaml and render via Hyrax's compound
# foundation. Literature has no geo_locations (see profile available_on).
class PortfolioLiteratureForm < Hyrax::Forms::ResourceForm(PortfolioLiterature)
  if Hyrax.config.work_include_metadata?
    include Hyrax::FormFields(:portfolio_literature)
    include Hyrax::FormFields(:bulkrax_metadata)
  end
  check_if_flexible(PortfolioLiterature)
end

PortfolioLiteratureResourceForm = PortfolioLiteratureForm unless defined?(PortfolioLiteratureResourceForm)
