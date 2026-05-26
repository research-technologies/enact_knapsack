# frozen_string_literal: true

# Form for PortfolioResource. Scalar fields come from the YAML schema via
# Hyrax::FormFields(:portfolio_resource). Compound fields land in a follow-up
# commit.
#
# @see https://github.com/samvera/hyrax/wiki/Hyrax-Valkyrie-Usage-Guide#forms
class PortfolioResourceForm < Hyrax::Forms::ResourceForm(PortfolioResource)
  if Hyrax.config.work_include_metadata?
    include Hyrax::FormFields(:portfolio_resource)
  end
  check_if_flexible(PortfolioResource)
end
