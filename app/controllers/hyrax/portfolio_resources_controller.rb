# frozen_string_literal: true

module Hyrax
  # Routes `/concern/portfolio_resources/*` for the PortfolioResource work
  # type. Mirrors the pattern Hyku uses for its built-in work-type controllers
  # (see hyrax-webapp/app/controllers/hyrax/oers_controller.rb).
  class PortfolioResourcesController < ::ApplicationController
    include Hyrax::WorksControllerBehavior
    include Hyku::WorksControllerBehavior
    include Hyrax::BreadcrumbsForWorks
    self.curation_concern_type = ::PortfolioResource

    self.work_form_service = Hyrax::FormFactory.new
  end
end
