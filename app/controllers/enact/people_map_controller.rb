# frozen_string_literal: true

module Enact
  # Read-only "research network" people map: contributors as nodes, linked where
  # they are credited on the same work, coloured by institution. The companion to
  # the work-to-work relationship map (Object Handling Spec v0.2 Sec 3.5) - same
  # visual language, same single source of truth (the works' `contributors`
  # compound), read through {Enact::PeopleGraph} and scoped to the viewer.
  #
  # This is still a react-to-it prototype (co-designed with Nick): the real graph
  # renders whenever the tenant has enough linked contributors; when the network
  # is too thin to be legible we fall back to an illustrative dataset and flag it
  # in the page, so a demo is never an empty canvas. Renders with `layout: false`.
  #
  # Knapsack-local custom code (Enact:: conventions, top-level namespace).
  class PeopleMapController < ApplicationController
    # Below this many real contributor nodes there is no network worth reading,
    # so we show the illustrative dataset (clearly banner-marked) instead of a
    # near-empty graph. Tune down to 1 once tenants carry real linked content.
    MIN_REAL_NODES = 4

    def show
      real = Enact::PeopleGraph.new(ability: current_ability).call.as_json
      @illustrative = real[:nodes].length < MIN_REAL_NODES
      @graph = @illustrative ? Enact::PeopleMapSample.data : real
      # `?focus=<contributor id>` centres the graph on one person and tiers the
      # rest as first-order (direct collaborators) vs second-order (adjacent
      # communities). This is how the "Research network" button on a contributor
      # profile opens the map. Ignored for the illustrative fallback, whose node
      # ids are sample slugs, not real contributor ids.
      @focus = @illustrative ? '' : params[:focus].to_s
      render layout: false
    end
  end
end
