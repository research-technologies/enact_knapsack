# frozen_string_literal: true

module Hyrax
  module Dashboard
    class JobStatusesController < ApplicationController
      layout 'hyrax/dashboard'

      before_action :authenticate_user!, :ensure_enabled

      def index
        @user_jobs = HykuKnapsack::UserJobs.for(current_user)
      end

      private

      def ensure_enabled
        return if Flipflop.job_statuses?

        redirect_to hyrax.my_works_path, alert: t('enact.job_statuses.disabled')
      end
    end
  end
end
