# frozen_string_literal: true

# OVERRIDE FILE from Hyrax v5.2.0
# - Modify params to allow editing of additional User columns
# - Ensure the current user matches the requested URL.
module Hyrax
  module Dashboard
    module ProfilesControllerDecoratorDecorator
      private

      def user_params
        params.require(:user).permit(:batch_email_frequency, :avatar, :facebook_handle, :twitter_handle,
                                     :googleplus_handle, :linkedin_handle, :remove_avatar, :orcid, :display_name)
      end
    end
  end
end

Hyrax::Dashboard::ProfilesControllerDecorator.prepend(Hyrax::Dashboard::ProfilesControllerDecoratorDecorator)
