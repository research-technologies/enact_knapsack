# frozen_string_literal: true

# OVERRIDE Hyrax v5.2.0 to keep the "Your activity" section open on the job statuses page.

module Hyrax
  module MenuPresenterDecorator
    def user_activity_section?
      super || controller.is_a?(Hyrax::Dashboard::JobStatusesController)
    end
  end
end

Hyrax::MenuPresenter.prepend(Hyrax::MenuPresenterDecorator)
