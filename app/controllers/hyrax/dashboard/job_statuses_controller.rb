# frozen_string_literal: true

module Hyrax
  module Dashboard
    class JobStatusesController < ApplicationController
      layout 'hyrax/dashboard'

      before_action :authenticate_user!

      def index
        @user_jobs = HykuKnapsack::UserJobs.for(current_user)
      end
    end
  end
end
