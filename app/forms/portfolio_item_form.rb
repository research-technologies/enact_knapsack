# frozen_string_literal: true

# Form for the legacy single-class PortfolioItem (kept for back-compat with
# existing data; new deposits go through PortfolioArtefact/Event/Literature/
# ItemCollection). Compound attributes live in
# config/metadata_profiles/m3_profile.yaml and render via Hyrax's compound
# foundation.
class PortfolioItemForm < Hyrax::Forms::ResourceForm(PortfolioItem)
  if Hyrax.config.work_include_metadata?
    include Hyrax::FormFields(:portfolio_item)
    include Hyrax::FormFields(:bulkrax_metadata)
  end
  check_if_flexible(PortfolioItem)
end

PortfolioItemResourceForm = PortfolioItemForm unless defined?(PortfolioItemResourceForm)
