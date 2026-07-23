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

      def grouped_for(user)
        self.for(user)
            .group_by { |job| file_set_id_for(job) }
            .filter_map do |file_set_id, jobs|
              { file_set_id:, jobs: } if file_set_id.present?
            end
      end

      def file_set_id_for(job)
        id = fetch_id(job)
        return nil if id.blank?
        return Hyrax.query_service.find_by(id:).file_set_id.to_s if characterization_job?(job)

        id
      rescue Valkyrie::Persistence::ObjectNotFoundError
        nil
      end

      private

      def characterization_job?(job)
        job.serialized_params.fetch('job_class', nil) == 'ValkyrieCharacterizationJob'
      end

      def ingest_job?(job)
        job.serialized_params.fetch('job_class', nil) == 'ValkyrieIngestJob'
      end

      def fetch_id(job)
        return fetch_id_from_uploaded_file(job) if ingest_job?(job)

        job_arguments(job).first
      end

      def fetch_id_from_uploaded_file(job)
        arguments = job_arguments(job).first
        return unless arguments

        uf_id = arguments['_aj_globalid'].split('/').last
        Hyrax::UploadedFile.find(uf_id).file_set_uri
      rescue ActiveRecord::RecordNotFound
        nil
      end

      def job_arguments(job)
        job.serialized_params.fetch('arguments', [])
      end
    end
  end
end
