# frozen_string_literal: true

module Enact
  # Admin-only linking of a Hyku User to an Enact::Contributor research profile
  # (1:1, enforced by a partial unique index on enact_contributors.user_id).
  #
  # Users ask for a profile (see ProfileRequestsController); this is where an
  # admin fulfills or declines. Candidate matching and the worklist query live in
  # Enact::ProfileLinker and Enact::ProfileWorklist.
  #
  # Knapsack-local custom code (Enact:: conventions, top-level namespace).
  #
  # rubocop:disable Metrics/ClassLength
  class UserProfileLinksController < ApplicationController
    layout 'hyrax/dashboard'

    before_action :authenticate_user!
    before_action :require_admin!

    def index
      @search = params[:q].to_s.strip
      worklist = Enact::ProfileWorklist.new(search: @search, page: params[:page])
      @request_count = worklist.request_count
      @unlinked_count = worklist.unlinked_count
      @users = worklist.users
      add_index_breadcrumbs
    end

    def new
      @user = find_linkable_user
      return if performed?

      load_request_history
      linker = Enact::ProfileLinker.new(@user)
      @search = params[:q].to_s.strip
      @orcid_match = linker.orcid_match
      @orcid_conflict = linker.orcid_conflict
      @suggestions = linker.suggestions
      dedupe_claimed_profile
      @results = linker.search(@search)
      @contributor ||= linker.build_profile
      add_new_breadcrumbs
    end

    def new_profile
      @user = find_linkable_user
      return if performed?

      @contributor ||= Enact::ProfileLinker.new(@user).build_profile
      add_new_profile_breadcrumbs
    end

    def create
      @user = find_linkable_user
      return if performed?

      params[:contributor_id].present? ? link_existing : create_and_link
    end

    def decline
      request = Enact::ProfileRequest.pending.find_by(id: params[:id])
      if request.nil?
        redirect_to worklist_path, alert: t('enact.research_profiles.admin.request_missing')
        return
      end

      request.decline!(by: current_user, note: review_note)
      redirect_to worklist_path, notice: t('enact.research_profiles.admin.declined')
    rescue ArgumentError
      redirect_to review_path(request.user), alert: t('enact.research_profiles.admin.decline_needs_reason')
    end

    # NOT `destroy`: this clears user_id and the profile itself survives, keeping
    # its metadata and work credits.
    def unlink
      contributor = contributor_for_unlink
      if contributor.nil?
        redirect_back fallback_location: worklist_path, alert: t('enact.research_profiles.admin.not_linked')
        return
      end

      contributor.update!(user_id: nil)
      redirect_to unlink_redirect_target(contributor), notice: t('enact.research_profiles.admin.unlinked')
    end

    private

    def load_request_history
      @profile_request = Enact::ProfileRequest.pending.find_by(user_id: @user.id)
      @claimed_profile = @profile_request&.contributor
      @past_declines = Enact::ProfileRequest.where(user_id: @user.id)
                                            .declined.order(reviewed_at: :desc)
    end

    def dedupe_claimed_profile
      return if @claimed_profile.blank?

      @orcid_match = nil if @orcid_match&.id == @claimed_profile.id
      @suggestions = @suggestions.reject { |c| c.id == @claimed_profile.id }
    end

    def link_existing
      contributor = find_linkable_contributor(params[:contributor_id])
      return if performed?

      apply_link(contributor, @user, redirect_to: worklist_path)
    end

    def create_and_link
      return redirect_to new_profile_path(@user) if params[:contributor].blank?

      contributor = Enact::Contributor.new(new_contributor_params)

      if contributor.save
        apply_link(contributor, @user, redirect_to: "/contributors/#{contributor.id}")
      else
        @contributor = contributor
        # new_profile can redirect (find_linkable_user), so rendering
        # unconditionally after it would raise DoubleRenderError.
        new_profile
        return if performed?

        render :new_profile, status: :unprocessable_entity
      end
    end

    # Same shape as ContributorsController#contributor_params: `affiliations` is
    # one-per-line text parsed into the model's jsonb array. agent_type is fixed
    # to 'person' — this profile is being created for a user account.
    def new_contributor_params
      permitted = params.require(:contributor).permit(:display_name, :orcid, :affiliations)
      permitted[:affiliations] = permitted[:affiliations].to_s.split("\n") if permitted.key?(:affiliations)
      permitted.merge(agent_type: 'person')
    end

    # Assign the link and resolve any pending request together. The partial
    # unique index is the real guarantee; rescuing it closes the window between
    # two admins acting on the same person.
    def apply_link(contributor, user, redirect_to:)
      Enact::Contributor.transaction do
        contributor.update!(user_id: user.id)
        Enact::ProfileRequest.pending.find_by(user_id: user.id)&.approve!(by: current_user)
      end
      redirect_to redirect_to, notice: t('enact.research_profiles.admin.linked', name: contributor.display_name)
    rescue ActiveRecord::RecordNotUnique
      redirect_to review_path(user), alert: t('enact.research_profiles.admin.already_linked')
    rescue ActiveRecord::RecordInvalid => e
      redirect_to review_path(user), alert: e.record.errors.full_messages.to_sentence
    end

    def find_linkable_user(id = params[:user_id])
      user = lookup_user(id)
      if user.nil?
        redirect_to worklist_path, alert: t('enact.research_profiles.admin.user_missing')
        return nil
      end
      return user if user.enact_contributor.blank?

      redirect_to worklist_path,
                  alert: t('enact.research_profiles.admin.user_already_linked',
                           name: user.enact_contributor.display_name)
      nil
    end

    # Hyrax overrides User#to_param to return an email-based slug
    # ("a-at-b-dot-com"), so every link built from a path helper arrives as a
    # slug rather than a numeric id. Accept both, since specs and any hand-built
    # URL will use the id.
    def lookup_user(id)
      return nil if id.blank?

      user = id.to_s.match?(/\A\d+\z/) ? ::User.find_by(id:) : ::User.from_url_component(id.to_s)
      # Without this a hand-built URL links another tenant's account to a profile
      # in this one. See Enact::ProfileWorklist#scoped_users.
      user if user && ::User.for_repository.exists?(id: user.id)
    end

    def find_linkable_contributor(id)
      contributor = Enact::Contributor.find_by(id:)
      if contributor.nil?
        redirect_to review_path(@user), alert: t('enact.research_profiles.admin.profile_missing')
        return nil
      end
      return contributor unless contributor.claimed?

      redirect_to review_path(@user), alert: t('enact.research_profiles.admin.profile_already_linked')
      nil
    end

    def contributor_for_unlink
      return Enact::Contributor.claimed.find_by(id: params[:contributor_id]) if params[:contributor_id].present?

      # params[:user_id] is a to_param slug when it came from a path helper.
      user = lookup_user(params[:user_id])
      user && Enact::Contributor.find_by(user_id: user.id)
    end

    # Return the admin to where they were
    def unlink_redirect_target(contributor)
      return worklist_path if request.referer.blank?
      return "/contributors/#{contributor.id}" if request.referer.include?("/contributors/#{contributor.id}")

      worklist_path
    end

    # The reviewer's reason for declining
    def review_note
      params.fetch(:profile_request, {}).permit(:review_note)[:review_note]
    end

    def worklist_path
      HykuKnapsack::Engine.routes.url_helpers.dashboard_research_profiles_path
    end

    def new_profile_path(user)
      HykuKnapsack::Engine.routes.url_helpers.new_dashboard_research_profile_path(user)
    end

    def review_path(user)
      HykuKnapsack::Engine.routes.url_helpers.new_dashboard_research_profile_link_path(user)
    end

    def add_index_breadcrumbs
      add_breadcrumb t('hyrax.controls.home', default: 'Home'), '/'
      add_breadcrumb t('enact.research_profiles.admin.title', default: 'Research profiles'), worklist_path
    end

    def add_new_breadcrumbs
      add_index_breadcrumbs
      add_breadcrumb @user.display_name.presence || @user.email,
                     HykuKnapsack::Engine.routes.url_helpers
                                         .new_dashboard_research_profile_link_path(@user)
    end

    def add_new_profile_breadcrumbs
      add_new_breadcrumbs
      add_breadcrumb t('enact.research_profiles.admin.create_title', default: 'New research profile'),
                     new_profile_path(@user)
    end

    def require_admin!
      return if can?(:manage, :research_profile_links)

      redirect_to main_app.root_path, alert: t('enact.research_profiles.admin.forbidden')
    end
  end
  # rubocop:enable Metrics/ClassLength
end
