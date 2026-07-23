# frozen_string_literal: true

module HykuKnapsack
  class UserJobs
    ALLOWED_JOBS = ['ValkyrieIngestJob', 'ValkyrieCharacterizationJob', 'ValkyrieCreateDerivativesJob', 'ValkyrieCreateLargeDerivativesJob'].freeze

    class << self
      def for(user)
        GoodJob::Job.where("serialized_params @> ?", { tenant: Apartment::Tenant.current, user_id: user.id }.to_json)
                    .where("serialized_params ->> 'job_class' IN (?)", ALLOWED_JOBS)
                    .order(created_at: :desc)
      end
    end
  end
end
