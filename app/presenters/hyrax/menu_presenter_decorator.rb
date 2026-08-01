# frozen_string_literal: true

# OVERRIDE Hyrax v5.2.0 to keep the "Your activity" section open on the knapsack's
# own pages in that section (job statuses, the user's research profile).

module Hyrax
  module MenuPresenterDecorator
    def user_activity_section?
      super ||
        controller.is_a?(Hyrax::Dashboard::JobStatusesController) ||
        controller.is_a?(Enact::ProfileRequestsController)
    end
  end
end

Hyrax::MenuPresenter.prepend(Hyrax::MenuPresenterDecorator)
