# frozen_string_literal: true

module Hyrax
  # Routes `/concern/portfolio_item_resources/*` for the PortfolioItemResource
  # work type. See PortfolioResourcesController for the pattern.
  class PortfolioItemResourcesController < ::ApplicationController
    include Hyrax::WorksControllerBehavior
    include Hyku::WorksControllerBehavior
    include Hyrax::BreadcrumbsForWorks
    self.curation_concern_type = ::PortfolioItemResource

    self.work_form_service = Hyrax::FormFactory.new
  end
end
