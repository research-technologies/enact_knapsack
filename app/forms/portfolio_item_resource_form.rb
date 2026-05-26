# frozen_string_literal: true

# Form for PortfolioItemResource. Scalar fields come from the YAML schema via
# Hyrax::FormFields(:portfolio_item_resource). Compound fields land in a
# follow-up commit.
class PortfolioItemResourceForm < Hyrax::Forms::ResourceForm(PortfolioItemResource)
  if Hyrax.config.work_include_metadata?
    include Hyrax::FormFields(:portfolio_item_resource)
  end
  check_if_flexible(PortfolioItemResource)
end
