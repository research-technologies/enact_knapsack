# frozen_string_literal: true

module Enact
  # Enact's deposit-wizard additions (the guided item-type sub-flow) layered on the
  # generic Hyku wizard. Type assistance is an Enact concept, not a Hyku one.
  module DepositWizard
    # How the work type is chosen on the add/standalone paths: pick it directly
    # (known) or infer it from the uploaded file (guided). Set on the item_start
    # step, stored in State#extra, and read by the flow's skip rules.
    TYPE_MODES = %w[known guided].freeze
  end
end
