# frozen_string_literal: true

module Enact
  # The user-facing side of research-profile claiming. An admin does the actual
  # linking (see UserProfileLinksController) — a request is a signal, not a grant.
  #
  # Every lookup is scoped to `current_user` so one user cannot act on another's request.
  #
  # Knapsack-local custom code (Enact:: conventions, top-level namespace).
  class ProfileRequestsController < ApplicationController
    layout 'hyrax/dashboard'

    before_action :authenticate_user!

    def show
      contributor = current_user.enact_contributor
      return redirect_to "/contributors/#{contributor.id}" if contributor.present?

      @pending_request = current_user.profile_requests.pending.first
      # The most recent decline, so a returning user learns their request was
      # actually considered
      @last_decline = current_user.profile_requests.declined.order(reviewed_at: :desc).first
      add_breadcrumb t('hyrax.controls.home', default: 'Home'), '/'
      add_breadcrumb t('enact.research_profiles.mine.title', default: 'Research profile'),
                     HykuKnapsack::Engine.routes.url_helpers.dashboard_research_profile_path
    end

    def create
      request = current_user.profile_requests.new(contributor_id: params[:contributor_id],
                                                  note: request_note)

      if request.save
        redirect_to after_create_path, notice: t('enact.research_profiles.requested')
      else
        redirect_to after_create_path, alert: request.errors.full_messages.to_sentence
      end
    rescue ActiveRecord::RecordNotUnique
      # The partial unique index on pending requests caught a double-submit.
      redirect_to after_create_path, alert: t('enact.research_profiles.already_requested')
    end

    def destroy
      request = current_user.profile_requests.pending.find_by(id: params[:id])
      if request.nil?
        redirect_to dashboard_path, alert: t('enact.research_profiles.request_missing')
        return
      end

      request.destroy
      redirect_to dashboard_path, notice: t('enact.research_profiles.withdrawn')
    end

    private

    def request_note
      params.fetch(:profile_request, {}).permit(:note)[:note]
    end

    def after_create_path
      return "/contributors/#{params[:contributor_id]}" if params[:contributor_id].present?

      dashboard_path
    end

    def dashboard_path
      HykuKnapsack::Engine.routes.url_helpers.dashboard_research_profile_path
    end
  end
end
