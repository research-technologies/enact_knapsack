# frozen_string_literal: true

# OVERRIDE Hyrax: cache the parsed schema definitions per profile version.
#
# In flexible mode every attribute render re-resolves the FlexibleSchema row
# and re-parses the whole m3 profile into M3AttributeDefinition objects. A
# single work show page does that ~90 times; a portfolio page renders a row
# per member work and multiplies it (observed on staging: 9,383 queries and
# 100+ seconds of view time for one portfolio page, which the load balancer
# surfaces as a 504 at its 60s timeout).
#
# A FlexibleSchema row is immutable once created - profile edits create a new
# row with a new id - so the parsed definitions can be memoized per
# (tenant, schema row id, schema name, contexts) for the life of the process.
# The tenant is part of the key because each Hyku tenant has its own
# hyrax_flexible_schemas table, so row ids collide across tenants.
module Hyrax
  module M3SchemaLoaderDecorator
    def self.cache
      @cache ||= Concurrent::Map.new
    end

    def self.clear_cache!
      @cache = Concurrent::Map.new
    end

    private

    def definitions(schema_name, version, contexts = nil)
      enact_cached(:definitions, schema_name, version, contexts) { super }
    end

    def raw_definitions(schema_name, version, contexts = nil)
      enact_cached(:raw_definitions, schema_name, version, contexts) { super }
    end

    # Key on the RESOLVED row id, not the requested version: resolve_schema
    # falls back to the latest row when the requested version is unknown, and
    # that fallback target changes when a new profile is imported. Skip the
    # cache entirely when no row resolves (early boot, fresh database).
    def enact_cached(kind, schema_name, version, contexts)
      schema_id = enact_resolved_schema_id(version)
      return yield if schema_id.nil?

      key = [
        Apartment::Tenant.current, schema_id, kind, schema_name.to_s,
        Array(contexts).map(&:to_s).sort.join(',')
      ].join('|')
      M3SchemaLoaderDecorator.cache.compute_if_absent(key) { yield }
    end

    # The row id `version` resolves to, skipping the database when we already
    # know. Only a DIRECT hit (row id == requested version) is memoized - a
    # fallback resolution (unknown version -> latest row) must stay live
    # because importing a new profile changes its answer.
    def enact_resolved_schema_id(version)
      id_key = "id|#{Apartment::Tenant.current}|#{version}"
      memoized = M3SchemaLoaderDecorator.cache[id_key]
      return memoized if memoized

      schema = resolve_schema(version)
      return nil if schema.nil?

      M3SchemaLoaderDecorator.cache[id_key] = schema.id if schema.id.to_s == version.to_s
      schema.id
    end
  end

  # OVERRIDE Hyrax: memoize FlexibleSchema.current_version / current_schema_id.
  #
  # This is the worst of the repeated work: WorkShowPresenter#define_dynamic_methods
  # runs on EVERY presenter (a portfolio page builds one per member row) and
  # calls current_version once PER PROPERTY - each call a fresh
  # `order(created_at).last` plus a full deserialize of the profile JSONB.
  # ~85 properties x one presenter per member is exactly the query storm seen
  # on staging.
  #
  # The memo is per tenant with a short TTL: the after_commit bust below
  # handles profile imports on THIS process, and the TTL bounds staleness on
  # other pods (a freshly imported profile is picked up within TTL seconds).
  module FlexibleSchemaLatestCaching
    TTL = 30.seconds

    def current_version
      enact_latest[:profile]
    end

    def current_schema_id
      enact_latest[:id]
    end

    def enact_clear_latest!
      @enact_latest = {}
    end

    private

    def enact_latest
      tenant = Apartment::Tenant.current
      @enact_latest ||= {}
      entry = @enact_latest[tenant]
      return entry[:value] if entry && entry[:expires_at] > Time.current

      row = order('created_at asc').last
      value = { id: row&.id, profile: row&.profile }
      @enact_latest[tenant] = { value: value, expires_at: TTL.from_now }
      value
    end
  end

  # Belt and braces: any write to a FlexibleSchema row (including the unusual
  # case of an in-place update) drops both memos for this process.
  module FlexibleSchemaCacheBusting
    extend ActiveSupport::Concern

    included do
      after_commit do
        Hyrax::M3SchemaLoaderDecorator.clear_cache!
        Hyrax::FlexibleSchema.enact_clear_latest!
      end
    end
  end
end

Hyrax::M3SchemaLoader.prepend(Hyrax::M3SchemaLoaderDecorator)
Hyrax::FlexibleSchema.singleton_class.prepend(Hyrax::FlexibleSchemaLatestCaching)
Hyrax::FlexibleSchema.include(Hyrax::FlexibleSchemaCacheBusting) unless
  Hyrax::FlexibleSchema.include?(Hyrax::FlexibleSchemaCacheBusting)
