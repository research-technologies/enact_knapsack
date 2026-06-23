# frozen_string_literal: true

module Enact
  module ContributorsHelper
    # Options for the browse-index person/organization filter: a leading "All"
    # (blank value = no filter) followed by one entry per agent_type enum value,
    # labeled from the locale. Returns [[label, value], ...] for options_for_select.
    def contributor_type_options
      all = [[t('enact.contributors.index.type_all', default: 'All'), '']]
      typed = Enact::Contributor.agent_types.keys.map do |type|
        [t("enact.contributors.types.#{type}", default: type.humanize), type]
      end
      all + typed
    end
  end
end
