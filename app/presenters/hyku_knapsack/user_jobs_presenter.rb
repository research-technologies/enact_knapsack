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
        state = state_for(job.status)
        {
          label: job.serialized_params['job_class'],
          name: name_for(job.serialized_params['job_class']),
          state:,
          error: job.error,
          elapsed: elapsed_for(job.performed_at, job.finished_at),
          meta: meta_for(state, job)
        }
      end

      def roll_up(states)
        return 'failed'   if states.include?('failed')
        return 'running'  if states.include?('running')
        return 'complete' if states.any? && states.all?('complete')

        'pending'
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

      def state_for(status)
        case status
        when :succeeded then 'complete'
        when :running, :retried then 'running'
        when :discarded then 'failed'
        else 'pending'
        end
      end

      def elapsed_for(start, stop)
        return if start.nil? || stop.nil?

        ActiveSupport::Duration.build((stop - start).to_i).parts.map { |unit, n| "#{n}#{unit.to_s.first}" }.join(' ').presence || '0s'
      end

      def meta_for(state, job)
        verb, at = case state
                   when 'complete' then ['Finished', job.finished_at]
                   when 'running'  then ['Started', job.performed_at]
                   when 'failed'   then ['Failed', job.finished_at]
                   end
        at && "#{verb} #{at.strftime('%-l:%M %p')}"
      end
    end

    def works
      return [] if file_set_ids.empty?

      work_hits.map { |hit| present_work(hit) }
    end

    private

    attr_reader :grouped, :file_set_ids

    def present_work(hit)
      file_sets = file_sets_for(hit)
      total = hit['member_ids_ssim'].count
      completed = completed(file_sets)
      untracked = [total - file_sets.size, 0].max
      state = self.class.roll_up(file_sets.map { |file_set| file_set[:state] } + Array.new(untracked, 'pending'))

      {
        work_id: hit['id'],
        model: hit.fetch('has_model_ssim', []).first,
        title: hit.fetch('title_tesim', []).join('; ').presence || 'Untitled',
        file_sets:, total:, completed:, state:,
        has_error: state == 'failed',
        pct: total.zero? ? 0 : (completed.to_f / total * 100).round,
        open: state != 'complete'
      }
    end

    def work_hits
      @work_hits ||= solr_query("member_ids_ssim:(#{file_set_ids.join(' OR ')})",
                          'id,title_tesim,member_ids_ssim,has_model_ssim', sort: 'date_modified_dtsi desc')
    end

    def solr_query(query, fields, sort: nil)
      Hyrax::SolrService.query(query, rows: file_set_ids.length, fl: fields, sort:)
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
        group[:state] = self.class.roll_up(group[:stages].map { |stage| stage[:state] })
        group[:open] = group[:state] != 'complete'
      end
    end

    def file_set_labels
      @file_set_labels ||= solr_query("id:(#{file_set_ids.join(' OR ')})", 'id,label_tesim')
    end

    def completed(file_sets)
      file_sets.count { |file_set| file_set[:completed].positive? && file_set[:completed] == file_set[:total] }
    end
  end
end
