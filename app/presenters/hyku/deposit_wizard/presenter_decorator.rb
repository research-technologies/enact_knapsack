# frozen_string_literal: true

# OVERRIDE Hyku::DepositWizard::Presenter to add the guided_confirm step Enact
# inserts after `files` (see config/initializers/deposit_wizard.rb).
#
# The generic presenter has no `guided_confirm` case; here we handle it and add
# the view helpers its template needs. Choosing a subtype is what sets the work
# type on the guided path (the subtype id resolves to exactly one of the four
# Portfolio types via Enact::DepositWizard::SubtypeSuggestions), the guided
# analogue of `select_work_type` on the known-type path.
#
# It also adds `portfolio_hierarchy` and `portfolio_hierarchy_summary`, which feed
# the review step's structural hierarchy card (issue #95).
module Hyku
  module DepositWizard
    module PresenterDecorator
      # OVERRIDE: route the steps Enact inserts (item_start records the type-choice
      # mode; guided_confirm resolves the chosen subtype to a work type). Every
      # other step, including a no-side-effect one, falls through to Hyku's
      # advance_from (which advances to the next visible step by default).
      def advance_from(step)
        case step
        when 'item_start'     then advance_from_item_start
        when 'guided_confirm' then advance_from_guided_confirm
        else super
        end
      end

      # The item_start step is Enact's "I know the type" / "help me decide" chooser;
      # the stored mode gates which type step (known_type or guided_confirm) shows
      # next. Stored in state.extra so Enact adds no slot to Hyku's State.
      def advance_from_item_start
        state.extra['type_mode'] = params[:type_mode] if Enact::DepositWizard::TYPE_MODES.include?(params[:type_mode])
        Transition.advance(next_step('item_start'))
      end

      # The primary uploaded file's display name (the uploader's stored filename,
      # the same accessor the file-step views use), or nil.
      def guided_primary_filename
        guided_primary_file&.file&.file&.filename&.to_s.presence
      end

      # The primary uploaded file's extension (lowercase, no dot), or nil when no
      # file is present — drives which subtypes are suggested.
      def guided_primary_extension
        name = guided_primary_filename
        return if name.nil?

        File.extname(name).delete_prefix('.').downcase.presence
      end

      # The uppercased file-type badge for the subtitle (e.g. "GIF"), matching the
      # file-detail step's badge. Nil when there is no primary file.
      def guided_file_badge
        file = guided_primary_file
        file && file_type_label(file)
      end

      # Subtypes suggested by the primary file's extension. Empty when there is no
      # file or nothing matches.
      def guided_suggestions
        ext = guided_primary_extension
        return [] if ext.nil?

        Enact::DepositWizard::SubtypeSuggestions.for_suffix(ext)
      end

      # The cards shown up front: the file's suggestions, or every subtype when the
      # file matched nothing (guided then acts as a plain subtype picker).
      def guided_primary_subtypes
        guided_suggestions.presence || guided_all_subtypes
      end

      # The subtypes held behind the "show all" toggle: everything not already shown
      # as a suggestion. Empty when the primary set is already the full list, so the
      # view can skip the toggle.
      def guided_more_subtypes
        return [] if guided_suggestions.empty?

        shown = guided_suggestions.map { |s| s[:id] }
        guided_all_subtypes.reject { |s| shown.include?(s[:id]) }
      end

      def guided_all_subtypes
        Enact::DepositWizard::SubtypeSuggestions.all_subtypes
      end

      # The subtype chosen so far (set on a prior visit), or nil. Drives the Next
      # button's initial enabled state so returning via Back can advance without
      # re-selecting.
      def guided_selected_subtype
        state.attributes['item_subtype'].presence
      end

      # nil unless nesting under a parent - only the "add to an existing work" path
      # has a hierarchy to show (issue #95).
      def portfolio_hierarchy
        return if state.parent_id.blank?

        Enact::PortfolioTree.new(ability: current_ability)
                            .for_deposit(parent_id: state.parent_id,
                                         pending: { label: Array(state.attributes['title']).first,
                                                    type: state.work_type })
      end

      def portfolio_hierarchy_summary(tree)
        # Count descendants only; the root Portfolio is not a "new"/"existing" item.
        counts = { 'new' => 0, 'existing' => 0 }
        stack = tree.children.dup
        until stack.empty?
          node = stack.pop
          counts[node.status] += 1 if counts.key?(node.status)
          stack.concat(node.children)
        end
        I18n.t('enact.portfolio_tree.summary', new: counts['new'], existing: counts['existing'])
      end

      private

      def guided_primary_file
        return uploaded_files.first if state.primary_file_id.blank?

        uploaded_files.find { |uf| uf.id.to_s == state.primary_file_id.to_s } || uploaded_files.first
      end

      def advance_from_guided_confirm
        id = params[:item_subtype].to_s
        work_type = Enact::DepositWizard::SubtypeSuggestions.work_type_for(id)
        return Transition.rerender('guided_confirm', alert: 'enact.deposit_wizard.errors.no_subtype') if work_type.blank?

        state.work_type = work_type
        # Seed the chosen subtype so the details form prefills it and it persists.
        state.attributes = state.attributes.merge('item_subtype' => id)
        Transition.advance(next_step('guided_confirm'))
      end
    end
  end
end

Hyku::DepositWizard::Presenter.prepend(Hyku::DepositWizard::PresenterDecorator)
