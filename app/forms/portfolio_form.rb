# frozen_string_literal: true

# Form for Portfolio. Scalar AND compound (`type: hash`) fields are declared
# in config/metadata_profiles/m3_profile.yaml; the Hyrax compound foundation
# routes compounds through `compound_terms` + `render_compound_field`, so the
# knapsack no longer needs to declare populators or build_permitted_params
# overrides.
class PortfolioForm < Hyrax::Forms::ResourceForm(Portfolio)
  if Hyrax.config.work_include_metadata?
    include Hyrax::FormFields(:portfolio)
    # Permit bulkrax_identifier so Bulkrax imports can round-trip the source
    # identifier through the resource form.
    include Hyrax::FormFields(:bulkrax_metadata)
  end
  check_if_flexible(Portfolio)
end

PortfolioResourceForm = PortfolioForm unless defined?(PortfolioResourceForm)
