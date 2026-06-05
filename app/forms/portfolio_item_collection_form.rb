# frozen_string_literal: true

# Form for PortfolioItemCollection. Compound attributes live in
# config/metadata_profiles/m3_profile.yaml and render via Hyrax's compound
# foundation. Collection has no geo_locations (see profile available_on).
class PortfolioItemCollectionForm < Hyrax::Forms::ResourceForm(PortfolioItemCollection)
  if Hyrax.config.work_include_metadata?
    include Hyrax::FormFields(:portfolio_item_collection)
    include Hyrax::FormFields(:bulkrax_metadata)
  end
  check_if_flexible(PortfolioItemCollection)
end

PortfolioItemCollectionResourceForm = PortfolioItemCollectionForm unless defined?(PortfolioItemCollectionResourceForm)
