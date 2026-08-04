# frozen_string_literal: true

module HykuKnapsack
  module ApplicationHelper
    include ::EnactThemeHelper
    # Explicit, not left to Rails' boot-time sweep of app/helpers: the relationships
    # card and the theme sidebar both call these, and upstream render_compound_cards
    # rescues a NoMethodError by returning nothing, so a helper the view cannot see
    # loses the whole card silently rather than erroring.
    include ::Enact::RelationshipMapHelper
  end
end
