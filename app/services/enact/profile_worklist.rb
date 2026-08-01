# frozen_string_literal: true

module Enact
  # Every user, ordered by what an admin can do about them: pending requests
  # first, then users with no profile, then users who have one.
  #
  # One list rather than filtered tabs, because a tab hides the very thing an
  # admin is often looking for — whether a given person is already linked.
  class ProfileWorklist
    PER_PAGE = 25

    # Joined rather than looked up per row so the grouping can happen in SQL.
    # Sorting after pagination would order only the current page, dropping a
    # requester whose email sorts late onto page 2 instead of leading the list.
    JOINS = <<~SQL.squish
      LEFT JOIN enact_profile_requests AS pending_requests
        ON pending_requests.user_id = users.id
       AND pending_requests.status = 'pending'
      LEFT JOIN enact_contributors AS linked_profiles
        ON linked_profiles.user_id = users.id
    SQL

    ORDER = <<~SQL.squish
      CASE
        WHEN pending_requests.id IS NOT NULL THEN 0
        WHEN linked_profiles.id IS NULL THEN 1
        ELSE 2
      END,
      pending_requests.created_at ASC NULLS LAST,
      users.email ASC
    SQL

    def initialize(search: nil, page: nil)
      @search = search.to_s.strip
      @page = page
    end

    def users
      filter(::User.all)
        .select('users.*, pending_requests.created_at AS requested_at')
        .joins(JOINS)
        .order(Arel.sql(ORDER))
        .page(@page).per(PER_PAGE)
    end

    def request_count
      ProfileRequest.pending.count
    end

    delegate :count, to: :unlinked, prefix: :unlinked

    private

    # `where.missing` needs User's has_one :enact_contributor (see UserDecorator).
    # Guests are excluded for free by User's default_scope.
    def unlinked
      ::User.where.missing(:enact_contributor)
    end

    def filter(relation)
      return relation if @search.blank?

      term = "%#{::User.sanitize_sql_like(@search)}%"
      relation.where('users.email ILIKE :t OR users.display_name ILIKE :t', t: term)
    end
  end
end
