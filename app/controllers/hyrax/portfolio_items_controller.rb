# frozen_string_literal: true

module Hyrax
  # Routes `/concern/portfolio_items/*` for the PortfolioItem work type. See
  # PortfoliosController for the pattern.
  class PortfolioItemsController < ::ApplicationController
    include Hyrax::WorksControllerBehavior
    include Hyku::WorksControllerBehavior
    include Hyrax::BreadcrumbsForWorks
    self.curation_concern_type = ::PortfolioItem

    self.work_form_service = Hyrax::FormFactory.new
  end
end
