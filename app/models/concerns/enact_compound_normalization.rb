# frozen_string_literal: true

# Defends `type: hash, multiple: true` compound attributes against a quirk in
# Valkyrie's Postgres orm_converter:
#
# * `EnumeratorValue#result`
#   (`valkyrie/persistence/shared/json_value_mapper.rb:121-128`) unwraps
#   single-element arrays to their first element.
# * `NestedRecord#result` then re-symbolizes the unwrapped Hash's keys.
# * The resource attribute type is `Array.of(Hash)`, so when dry-struct
#   coerces the single Hash back into an Array it calls `Array(hash)`, which
#   splays a Hash into `[[:key, value], ...]` pairs.
#
# Net effect: a saved `[{a: 1, b: 2}]` reads back as `[[:a, 1], [:b, 2]]`.
#
# `set_value` covers the form-driven write path (it's the entry point for
# `resource.foo = ...` setters), and the prepended reader covers the read
# path, which bypasses `set_value` during `Resource.new(attrs)` construction
# from the persister. Both layers transform_keys so downstream code (form
# partial, indexer) can rely on string keys.
module EnactCompoundNormalization
  COMPOUND_ATTRS = %i[contributors identifiers funding_references organisational_units
                      geo_locations licenses].freeze

  def set_value(key, value)
    super(key, COMPOUND_ATTRS.include?(key.to_sym) ? normalize_compound(value) : value)
  end

  COMPOUND_ATTRS.each do |attr|
    define_method(attr) { normalize_compound(super()) }
  end

  private

  def normalize_compound(value)
    return value if value.nil?
    arr = value.is_a?(::Array) ? value : [value]
    pair_array = arr.length.positive? &&
                 arr.all? { |e| e.is_a?(::Array) && e.length == 2 && (e.first.is_a?(::Symbol) || e.first.is_a?(::String)) }
    rows = pair_array ? [::Hash[arr]] : arr
    rows.map { |entry| entry.is_a?(::Hash) ? entry.transform_keys(&:to_s) : entry }
  end
end
