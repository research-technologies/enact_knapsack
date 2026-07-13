# frozen_string_literal: true

# OVERRIDE Hyrax 5.2.0 (samvera/hyrax main @ 568ec626)
#
# Block non-admins from reaching the User Collection create form/action
# directly (e.g. typing /dashboard/collections/new), on top of hiding the
# sidebar link. Hyrax only authorizes `new`/`create` against the collection
# type's create participants, so a tenant whose "User Collection" type still
# grants create to depositors leaves the form reachable by URL even when the
# UI hides the button. We gate creation on the same admin check the sidebar
# uses (`can? :read, :admin_dashboard`) so the two stay consistent and the
# guard holds regardless of per-tenant collection-type configuration.
#
# See research-technologies/enact_knapsack#94.
module Hyrax
  module Dashboard
    module CollectionsControllerDecorator
      def self.prepended(base)
        base.before_action :require_admin_to_create_collection, only: %i[new create]
      end

      private

      # Raises CanCan::AccessDenied for non-admins, which the controller's
      # existing `rescue_from ... :deny_collection_access` turns into a
      # redirect (to root for signed-in users, to login otherwise).
      def require_admin_to_create_collection
        authorize! :read, :admin_dashboard
      end
    end
  end
end

Hyrax::Dashboard::CollectionsController.prepend(Hyrax::Dashboard::CollectionsControllerDecorator)
