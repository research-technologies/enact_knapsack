# frozen_string_literal: true

module Enact
  # Public, read-only contributor profile page. Loads the contributor and the
  # works crediting them (access-scoped to the viewer). The claimed/unclaimed
  # indicator and "claim" CTA are built out in a later step. No auth: contributor
  # profiles are public, but the works list only shows works the viewer may see.
  #
  # Knapsack-local custom code (Enact:: conventions, top-level namespace).
  class ContributorsController < ApplicationController
    # Editing a contributor profile is admin-gated for now: a contributor has no
    # owner until the (deferred) claim flow exists, so only admins/curators may
    # curate one. Index/show stay public.
    before_action :require_admin!, only: %i[edit update]
    # Browse all contributors (linked from the home page Featured Researcher
    # tab). Optional free-text search (name / ORCID) and person/organization
    # filter narrow the list server-side; alphabetical and paginated.
    def index
      @search = params[:q].to_s.strip
      @agent_type = params[:agent_type].to_s.presence_in(Enact::Contributor.agent_types.keys)

      scope = Enact::Contributor.all
      scope = scope.matching(@search) if @search.present?
      scope = scope.where(agent_type: @agent_type) if @agent_type
      @contributors = scope.order(:display_name).page(params[:page]).per(24)
    end

    def show
      @contributor = Enact::Contributor.find(params[:id])
      # Works crediting this contributor, scoped to what the viewer may see.
      @works = Enact::ContributorGraph.new(@contributor, ability: current_ability).works
      add_show_breadcrumbs
    end

    def edit
      @contributor = Enact::Contributor.find(params[:id])
    end

    def update
      @contributor = Enact::Contributor.find(params[:id])
      if @contributor.update(contributor_params)
        redirect_to "/contributors/#{@contributor.id}",
                    notice: t('enact.contributors.edit.updated', default: 'Profile updated.')
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    # Feed the layout's breadcrumb trail (rendered by `render_breadcrumbs` in the
    # Hyrax layout) so the profile page links back to the index. Done via crummy's
    # `add_breadcrumb` rather than a hand-rolled view breadcrumb, so there is a
    # single, consistently-styled trail. Literal paths match the knapsack idiom
    # for these engine-namespaced routes.
    def add_show_breadcrumbs
      add_breadcrumb t('hyrax.controls.home', default: 'Home'), '/'
      add_breadcrumb t('enact.contributors.index.title', default: 'Research profiles'), '/contributors'
      # The trailing crumb needs an explicit path too: the breadcrumbs_on_rails
      # builder computes a path for every element, and our custom (non-RESTful)
      # routes don't resolve from the implicit controller/action.
      add_breadcrumb @contributor.display_name, "/contributors/#{@contributor.id}"
    end

    # Strong params: the identity fields an admin may curate. Both multi-valued
    # fields are entered as one-per-line text and parsed into the model's jsonb
    # arrays (the model writers trim and drop blanks): `affiliations` is plain
    # strings; `name_identifiers` is `value | scheme` per line, split into
    # { value:, scheme: } hashes.
    def contributor_params
      permitted = params.require(:contributor).permit(:display_name, :agent_type, :orcid,
                                                      :affiliations, :name_identifiers)
      permitted[:affiliations] = permitted[:affiliations].to_s.split("\n") if permitted.key?(:affiliations)
      permitted[:name_identifiers] = parse_name_identifiers(permitted[:name_identifiers]) if permitted.key?(:name_identifiers)
      permitted
    end

    # Parse the `name_identifiers` textarea (one `value | scheme` per line) into
    # the model's array-of-hashes shape; the model writer drops blank-value rows.
    def parse_name_identifiers(text)
      text.to_s.split("\n").map do |line|
        value, scheme = line.split('|', 2).map(&:strip)
        { 'value' => value, 'scheme' => scheme }
      end
    end

    # Phase 1 gate: only admins/curators may edit a profile (no owner/claim yet).
    # Mirrors the standard Hyku admin check; redirects others to the public show.
    def require_admin!
      return if current_ability.admin?

      redirect_to "/contributors/#{params[:id]}",
                  alert: t('enact.contributors.edit.forbidden', default: 'You are not authorized to edit this profile.')
    end
  end
end
