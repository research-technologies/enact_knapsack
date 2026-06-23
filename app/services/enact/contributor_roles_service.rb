# frozen_string_literal: true

module Enact
  # Authority-backed service for the contributor role vocabulary
  # (config/authorities/contributor_roles.yml) — the 14 NISO CRediT terms plus
  # the practice-research roles CRediT does not cover. Mirrors the way Hyrax
  # exposes its own controlled vocabularies (e.g. Hyrax::ResourceTypesService,
  # Hyrax::DisciplineService) by extending Hyrax::AuthorityService, which
  # provides `authority`, `select_options`, `label`, and `active?` for free.
  #
  # A `contributors` compound entry stores the authority `id` code (e.g.
  # "data-curation"), never the label, exactly as `relationship_type` stores
  # "source-of". The same `contributor_roles` authority backs the deposit
  # dropdown (the m3 `contributor_role` subproperty declares
  # `authority: contributor_roles`), so the deposit vocabulary and these lookups
  # are one source of truth.
  #
  # Beyond the standard label/active API, each authority term carries the
  # interop metadata a future DOI/RAiD/ORCID minter needs (`credit_uri`,
  # `datacite`, `marc`); the accessors below expose it by reading the full term
  # hash, which Hyrax::AuthorityService / the QA local authority preserve. The
  # minter itself — emitting a DataCite `contributorType` / CRediT role URI and
  # stamping a RAiD into `relatedIdentifiers` — is NOT built yet; this is only
  # the seam it will plug into.
  module ContributorRolesService
    extend Hyrax::AuthorityService

    authority_name 'contributor_roles'

    module_function

    # All role codes, in authority (declared) order: CRediT first, then practice.
    def codes
      select_all_options.map { |(_label, id)| id }
    end

    # CRediT role URI, or nil for a practice role / unknown code.
    def credit_uri(code)
      authority.find(code.to_s)['credit_uri']
    end

    # DataCite contributorType for the code, "Other" for an unknown code so a
    # minter always has a valid DataCite value to emit.
    def datacite(code)
      authority.find(code.to_s)['datacite'] || 'Other'
    end

    # MARC relator code where one fits, else nil.
    def marc(code)
      authority.find(code.to_s)['marc']
    end
  end
end
