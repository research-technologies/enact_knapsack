# frozen_string_literal: true

module Enact
  # Authority-backed service for config/authorities/relationship_types.yml,
  # mirroring Enact::ContributorRolesService. Each term declares its own
  # `inverse:` and optional `color:`, so adding a relationship type is a YAML
  # edit; nothing here changes.
  module RelationshipTypesService
    extend Hyrax::AuthorityService

    authority_name 'relationship_types'

    FALLBACK_COLOR = '#9aa0a6'

    module_function

    # How the edge reads from the target's point of view. An unknown or
    # inverse-less code falls back to itself, matching how unmapped types have
    # always displayed.
    def inverse(code)
      term(code)['inverse'].presence || code.to_s
    end

    def color(code)
      term(code)['color'].presence || FALLBACK_COLOR
    end

    def label(code)
      term(code)['term'].presence || code.to_s.tr('-', ' ').capitalize
    end

    def datacite(code)
      term(code)['datacite']
    end

    def term(code)
      authority.find(code.to_s) || {}
    end
  end
end
