# frozen_string_literal: true

# OVERRIDE Hyrax 5.2.0 (samvera/hyrax @ 14fdd67): relabel the `authenticated`
# visibility badge (notch8/enact_knapsack#84).
#
# Upstream PermissionBadge#text special-cases `authenticated` to
# `Hyrax::Institution.name` (I18n.t('hyrax.institution_name') = "Institution"),
# bypassing the `hyrax.visibility.authenticated.text` locale key entirely. For a
# national multi-tenant service that reads wrong: authenticated visibility just
# means "any signed-in user", not institutional (IP/SSO) access. We route it back
# through the locale so it renders "Logged-in users" instead. We do NOT change
# `hyrax.institution_name` because it is shared with unrelated permission UI.
module Hyrax
  module PermissionBadgeDecorator
    private

    def text
      return I18n.t('hyrax.visibility.authenticated.text') if registered?

      super
    end
  end
end

Hyrax::PermissionBadge.prepend(Hyrax::PermissionBadgeDecorator)
