# frozen_string_literal: true

# OVERRIDE Hyrax 5.2.0 (samvera/hyrax @ 14fdd67): relabel the `authenticated`
# visibility option in the Sharing-tab dropdown (notch8/enact_knapsack#84).
#
# Upstream AbilityHelper#visibility_text special-cases `authenticated` to
# `institution_name`, matching PermissionBadge. This feeds `visibility_options`,
# the visibility <select> on a work's Sharing tab. Route it through the same
# locale key the badge now uses so both read "Logged-in users". See
# Hyrax::PermissionBadgeDecorator for the badge-side change.
module Hyrax
  module AbilityHelperDecorator
    private

    def visibility_text(value)
      return I18n.t('hyrax.visibility.authenticated.text') if value == Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_AUTHENTICATED

      super
    end
  end
end

Hyrax::AbilityHelper.prepend(Hyrax::AbilityHelperDecorator)
