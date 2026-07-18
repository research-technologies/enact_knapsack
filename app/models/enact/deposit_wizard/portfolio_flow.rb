# frozen_string_literal: true

module Enact
  module DepositWizard
    # Builds Enact's branching wizard Flow (assigned to config.flow). Three intents
    # are chosen on `start`, and the type is chosen either directly (known) or by
    # inferring it from the uploaded file (guided):
    #
    #   new        -> work_type set to the container at start; item_start + both
    #                 type steps skip:  start -> files -> details -> ...
    #   add        -> select_parent -> item_start -> files -> (known|guided) -> ...
    #   standalone ->                   item_start -> files -> (known|guided) -> ...
    #
    # Files come before the type step because `files` has no work_type prerequisite,
    # so the guided step can infer the type from what was uploaded. Skip rules are
    # named below so the step list reads as the flow, not as lambdas.
    module PortfolioFlow
      module_function

      def build
        flow = Hyku::DepositWizard::Flow
        flow.new(steps(flow::Step))
      end

      def steps(step) # rubocop:disable Metrics/MethodLength
        [
          step.new(name: 'start', rail_key: :type, icon: 'fa-list-alt', label_key: 'type'),
          step.new(name: 'select_parent',
                   skip_if: unless_adding, on_skip: :entry,
                   rail_key: :parent, rail_if: when_adding,
                   icon: 'fa-sitemap', label_key: 'parent'),
          step.new(name: 'item_start', skip_if: on_new_path, rail_key: :type),
          step.new(name: 'files', rail_key: :upload, icon: 'fa-cloud-upload', label_key: 'upload'),
          step.new(name: 'known_type', skip_if: unless_type_mode('known'), rail_key: :type),
          step.new(name: 'guided_confirm', skip_if: unless_type_mode('guided'), rail_key: :type),
          step.new(name: 'details', requires: %i[work_type],
                   rail_key: :detail, icon: 'fa-pencil', label_key: 'detail'),
          step.new(name: 'file_meta', requires: %i[work_type],
                   skip_if: without_files, rail_key: :file_detail, rail_if: with_files,
                   icon: 'fa-file-text-o', label_key: 'file_detail'),
          step.new(name: 'review', requires: %i[work_type],
                   rail_key: :review, icon: 'fa-check', label_key: 'review'),
          step.new(name: 'done', terminal: true)
        ]
      end

      def unless_adding = ->(state, _config) { state.path != 'add' }
      def when_adding   = ->(state, _config) { state.path == 'add' }
      def on_new_path   = ->(state, _config) { state.path == 'new' }
      def without_files = ->(state, _config) { state.uploaded_file_ids.empty? }
      def with_files    = ->(state, _config) { state.uploaded_file_ids.any? }

      # Hide a type step unless the depositor picked its mode on item_start. The
      # mode lives in state.extra (Enact adds no slot to Hyku's State).
      def unless_type_mode(mode)
        ->(state, _config) { state.extra['type_mode'] != mode }
      end
    end
  end
end
