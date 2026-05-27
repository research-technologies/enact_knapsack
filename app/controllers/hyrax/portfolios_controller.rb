# frozen_string_literal: true

module Hyrax
  # Routes `/concern/portfolios/*` for the Portfolio work type. Mirrors the
  # pattern Hyku uses for its built-in work-type controllers (see
  # `hyrax-webapp/app/controllers/hyrax/oers_controller.rb`).
  class PortfoliosController < ::ApplicationController
    include Hyrax::WorksControllerBehavior
    include Hyku::WorksControllerBehavior
    include Hyrax::BreadcrumbsForWorks
    self.curation_concern_type = ::Portfolio

    self.work_form_service = Hyrax::FormFactory.new
  end
end
