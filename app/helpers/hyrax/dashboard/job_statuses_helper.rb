# frozen_string_literal: true

module Hyrax
  module Dashboard
    module JobStatusesHelper
      def job_status_work_path(work)
        doc = ::SolrDocument.new(id: work[:work_id], has_model_ssim: [work[:model]])
        main_app.polymorphic_path(doc)
      end

      def job_status_file_set_path(file_set)
        main_app.hyrax_file_set_path(file_set[:file_set_id])
      end

      def job_status_error(stage)
        stage[:error]&.truncate(200)
      end
    end
  end
end
