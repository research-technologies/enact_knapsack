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

      # Accessible tint badge class per state (see job_activity.scss); Bootstrap's
      # solid badge-* fills fail WCAG AA contrast.
      def job_status_badge_class(state)
        { 'complete' => 'job-badge-complete', 'running' => 'job-badge-running',
          'retrying' => 'job-badge-retrying', 'failed' => 'job-badge-failed' }.fetch(state, 'job-badge-queued')
      end

      # Progress-bar fill class for a stage bar/segment; pending reads as empty track.
      def job_status_bar_class(state)
        case state
        when 'complete' then 'bg-success'
        when 'running'  then 'bg-info progress-bar-striped progress-bar-animated'
        when 'retrying' then 'bg-warning progress-bar-striped progress-bar-animated'
        when 'failed'   then 'bg-danger'
        else '' # pending: empty
        end
      end

      def job_status_dot_class(state)
        case state
        when 'complete'            then 'job-dot-done'
        when 'failed'              then 'job-dot-error job-dot-error-glow'
        when 'running', 'retrying' then 'job-dot-active job-dot-pulse'
        else 'job-dot-active'
        end
      end
    end
  end
end
