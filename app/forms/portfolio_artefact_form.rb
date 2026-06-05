# frozen_string_literal: true

# Form for PortfolioArtefact. All compound (`type: hash`) attributes are
# declared on `config/metadata_profiles/m3_profile.yaml` and routed through
# Hyrax's compound foundation (see hyrax PR / nested-compound-metadata-foundation
# branch + hyku PR #3093). Scalar fields come from the YAML schema via
# Hyrax::FormFields(:portfolio_artefact).
class PortfolioArtefactForm < Hyrax::Forms::ResourceForm(PortfolioArtefact)
  if Hyrax.config.work_include_metadata?
    include Hyrax::FormFields(:portfolio_artefact)
    include Hyrax::FormFields(:bulkrax_metadata)
  end
  check_if_flexible(PortfolioArtefact)
end

PortfolioArtefactResourceForm = PortfolioArtefactForm unless defined?(PortfolioArtefactResourceForm)
