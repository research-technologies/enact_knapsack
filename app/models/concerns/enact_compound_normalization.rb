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
# We intercept at three layers:
#   - `klass.new(attrs)` (class-level, via singleton_class.prepend) so
#     dry-struct's strict type coercion never sees a splayed pair array
#     during reload from the persister.
#   - `set_value` (instance, write path).
#   - per-compound reader (instance, read path).
module EnactCompoundNormalization
  COMPOUND_ATTRS = %i[titles dates contributors identifiers funding_references
                      organisational_units geo_locations licenses].freeze

  # Prepended onto the host class's singleton so it wins over Dry::Struct's
  # own `.new`. Pre-normalizes compound attrs BEFORE dry-struct's strict
  # type coercion runs (required for Hyrax 5.2+).
  module ClassOverrides
    def new(attrs = {}, *args)
      attrs = EnactCompoundNormalization.normalize_attrs(attrs) if attrs.is_a?(::Hash)
      super
    end
  end

  def self.prepended(base)
    base.singleton_class.prepend(ClassOverrides)
  end

  def set_value(key, value)
    super(key, COMPOUND_ATTRS.include?(key.to_sym) ? EnactCompoundNormalization.normalize_compound(value) : value)
  end

  COMPOUND_ATTRS.each do |attr|
    define_method(attr) { EnactCompoundNormalization.normalize_compound(super()) }
  end

  # @api private
  def self.normalize_attrs(attrs)
    attrs = attrs.dup
    COMPOUND_ATTRS.each do |key|
      [key, key.to_s].each do |k|
        attrs[k] = normalize_compound(attrs[k]) if attrs.key?(k)
      end
    end
    attrs
  end

  # @api private
  def self.normalize_compound(value)
    return value if value.nil?
    arr = value.is_a?(::Array) ? value : [value]
    arr = collapse_pair_array(arr) || collapse_flat_pair(arr) || arr
    arr.map { |entry| entry.is_a?(::Hash) ? entry.transform_keys(&:to_s) : entry }
  end

  # Multi-key splay: `[[:a, 1], [:b, 2]]` -> `[{a: 1, b: 2}]`. Returns nil
  # if the input doesn't look like a pair array.
  def self.collapse_pair_array(arr)
    return nil if arr.empty?
    return nil unless arr.all? { |e| pair?(e) }
    [::Hash[arr]]
  end

  # Single-key collapse: `["a", 1]` -> `[{"a" => 1}]`. Returns nil if the
  # input doesn't look like a single flat pair.
  def self.collapse_flat_pair(arr)
    return nil unless arr.length == 2
    return nil unless arr.first.is_a?(::Symbol) || arr.first.is_a?(::String)
    return nil if arr.last.is_a?(::Hash) || arr.last.is_a?(::Array)
    [::Hash[[arr]]]
  end

  def self.pair?(element)
    element.is_a?(::Array) &&
      element.length == 2 &&
      (element.first.is_a?(::Symbol) || element.first.is_a?(::String))
  end
end
