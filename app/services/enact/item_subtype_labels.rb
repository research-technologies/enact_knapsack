# frozen_string_literal: true

module Enact
  # Labels an item_subtype URI for display.
  #
  # item_subtype draws from four authorities (one per work type), but Hyrax resolves
  # a controlled property against one: `controlled_values.sources` is read
  # first-entry-only, so no profile config labels all four. Subtype ids are globally
  # unique across the files (asserted in the SubtypeSuggestions spec), so the id
  # alone identifies the term.
  module ItemSubtypeLabels
    module_function

    # @param value [String, nil] a subtype URI
    # @return [String, nil] its label, or +value+ unchanged when unrecognized
    def label_for(value)
      return value if value.blank?

      Enact::DepositWizard::SubtypeSuggestions.find(value)&.dig(:label) || value
    end
  end
end
