# frozen_string_literal: true

module Enact
  # A user's request for a research profile, forming the admin work queue.
  #
  # A request is a signal, not a grant: an admin still confirms identity before
  # linking. Reviewed requests are kept rather than deleted, so a repeat request
  # shows the admin it was considered before.
  class ProfileRequest < HykuKnapsack::ApplicationRecord
    self.table_name = 'enact_profile_requests'

    belongs_to :user, class_name: '::User', inverse_of: :profile_requests
    belongs_to :contributor, class_name: 'Enact::Contributor', optional: true
    belongs_to :reviewed_by, class_name: '::User', optional: true

    enum :status, { pending: 'pending', approved: 'approved', declined: 'declined' }, default: 'pending'

    # One OPEN request per user (a partial unique index on `status = 'pending'`
    # is the DB-level guarantee; this surfaces a clean error). Scoped to pending
    # so a declined request never permanently bars someone from asking again.
    validates :user_id, uniqueness: { conditions: -> { where(status: 'pending') } }, if: :pending?

    validate :contributor_must_be_unclaimed
    validate :user_must_not_have_a_profile, on: :create

    scope :for_user, ->(user) { where(user:) }
    scope :oldest_first, -> { order(:created_at) }

    # Records the decision only — linking the profile is what fulfills the
    # request, so callers must do both in one transaction.
    def approve!(by:)
      update!(status: 'approved', reviewed_by: by, reviewed_at: Time.current)
    end

    # The reason is written to `review_note`, and shown back to the requester
    def decline!(by:, note:)
      raise ArgumentError, 'a decline needs a reason' if note.blank?

      update!(status: 'declined', reviewed_by: by, reviewed_at: Time.current,
              review_note: note.strip)
    end

    def claim?
      contributor_id.present?
    end

    private

    def contributor_must_be_unclaimed
      return if contributor.blank? || !contributor.claimed?

      errors.add(:contributor, :already_claimed,
                 message: I18n.t('enact.research_profiles.errors.contributor_claimed',
                                 default: 'is already linked to another user'))
    end

    def user_must_not_have_a_profile
      return if user.blank? || user.enact_contributor.blank?

      errors.add(:user, :already_linked,
                 message: I18n.t('enact.research_profiles.errors.user_linked',
                                 default: 'already has a research profile'))
    end
  end
end
