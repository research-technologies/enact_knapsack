# frozen_string_literal: true

module HykuKnapsack
  class UserJobsPresenter
    def initialize(grouped:)
      @grouped = grouped
      @file_set_ids = grouped.pluck(:file_set_id)
      add_extra_info! if @file_set_ids.any?
    end

    class << self
      def stage_for(job)
        status = job.status
        attempts = job.executions_count

        {
          label: job.serialized_params['job_class'],
          name: name_for(job.serialized_params['job_class']),
          status:,
          error: job.error,
          attempts:,
          status_label: status_label_for(status, attempts),
          variant: variant_for(status)
        }
      end

      private

      def name_for(job_class)
        {
          'ValkyrieIngestJob' => 'Ingest',
          'ValkyrieCharacterizationJob' => 'Characterize',
          'ValkyrieCreateDerivativesJob' => 'Derivative',
          'ValkyrieCreateLargeDerivativesJob' => 'Derivative'
        }[job_class]
      end

      def status_label_for(status, attempts)
        case status
        when :succeeded then 'Complete'
        when :running   then 'Running'
        when :retried   then "Retrying (attempt #{attempts})"
        when :discarded then "Failed after #{attempts} attempts"
        else 'Pending'
        end
      end

      def variant_for(status)
        {
          succeeded: :success,
          running: :primary,
          retried: :warning,
          discarded: :danger
        }.fetch(status, :secondary)
      end
    end

    def works
      return [] if file_set_ids.empty?

      work_hits.map do |hit|
        file_sets = file_sets_for(hit)
        total = hit['member_ids_ssim'].count
        completed = completed(file_sets)

        {
          work_id: hit['id'],
          model: hit.fetch('has_model_ssim', []).first,
          title: hit.fetch('title_tesim', []).join('; ').presence || 'Untitled',
          file_sets:,
          total:,
          completed:
        }
      end
    end

    private

    attr_reader :grouped, :file_set_ids

    def work_hits
      @work_hits ||=
        Hyrax::SolrService.query(
          "member_ids_ssim:(#{file_set_ids.join(' OR ')})",
          rows: file_set_ids.length,
          fl: 'id,title_tesim,member_ids_ssim,has_model_ssim',
          sort: 'date_modified_dtsi desc'
        )
    end

    def file_sets_for(hit)
      fs_ids = hit['member_ids_ssim']
      grouped.select { |group| fs_ids.include?(group[:file_set_id]) }
    end

    def add_extra_info!
      labels_by_id = file_set_labels.index_by { |hit| hit['id'] }
      grouped.each do |group|
        group[:label] = labels_by_id[group[:file_set_id]]&.fetch('label_tesim', [])&.first || 'Untitled'
        group[:total] = group[:jobs].count
        group[:completed] = group[:jobs].count(&:succeeded?)
        group[:stages] = group[:jobs].sort_by(&:created_at).map { |job| self.class.stage_for(job) }
      end
    end

    def file_set_labels
      @file_set_labels ||=
        Hyrax::SolrService.query(
          "id:(#{file_set_ids.join(' OR ')})",
          rows: file_set_ids.length,
          fl: 'id,label_tesim'
        )
    end

    def completed(file_sets)
      file_sets.count { |file_set| file_set[:completed].positive? && file_set[:completed] == file_set[:total] }
    end
  end
end
