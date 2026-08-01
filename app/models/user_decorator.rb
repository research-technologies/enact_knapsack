# frozen_string_literal: true

# OVERRIDE Hyku v6.0.0 to link a User to their Enact::Contributor research profile
#
# A User has at most one research profile. The link is admin-approved and opt-in:
# profiles are never auto-created with an account (many users may not want one),
# and users ask for one via Enact::ProfileRequest.
module UserDecorator
  extend ActiveSupport::Concern

  prepended do
    # dependent: nil is explicit, not an oversight. A research profile is curated
    # repository metadata that credits works — it outlives the account and must
    # survive the user's deletion. Do not "fix" this to :destroy.
    has_one :enact_contributor,
            class_name: 'Enact::Contributor',
            inverse_of: :user,
            dependent: nil

    has_many :profile_requests,
             class_name: 'Enact::ProfileRequest',
             inverse_of: :user,
             dependent: :destroy
  end

  def research_profile?
    enact_contributor.present?
  end
end

User.prepend(UserDecorator)
