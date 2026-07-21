# frozen_string_literal: true
require 'active_job'
require 'hyku_knapsack/active_job_user'

class ActiveJob::Base
  include HykuKnapsack::ActiveJobUser
end
