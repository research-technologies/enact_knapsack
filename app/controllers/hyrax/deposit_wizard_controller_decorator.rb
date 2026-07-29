# frozen_string_literal: true

# OVERRIDE Hyrax::DepositWizardController (hyrax-webapp submodule @ 0dbacbce,
# app/controllers/hyrax/deposit_wizard_controller.rb) to carry the deposited
# work's id and its parent's id onto the done screen. The confirmation view
# renders the Portfolio hierarchy card there once the work is actually saved
# (issue #95 - card moved from the review step to done per LaRita's review).
module Hyrax
  module DepositWizardControllerDecorator
    private

    # #commit calls reset_state before stash_deposited, but that only swaps the
    # session hash for a fresh one; the in-memory wizard_state still holds the
    # parent_id chosen this session, so it survives long enough to stash here.
    def stash_deposited(work)
      super
      session[:deposit_wizard_last].merge!(
        'id' => work.id.to_s,
        'parent_id' => wizard_state.parent_id.presence
      )
    end
  end
end

Hyrax::DepositWizardController.prepend(Hyrax::DepositWizardControllerDecorator)
