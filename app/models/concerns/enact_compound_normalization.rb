# frozen_string_literal: true

# Defends `type: hash, multiple: true` compound attributes against a quirk in
# Valkyrie's Postgres orm_converter:
#
# * `EnumeratorValue#result`
#   (`valkyrie/persistence/shared/json_value_mapper.rb:121-128`) unwraps
#   single-element arrays to their first element - and because a Hash also
#   responds to `#each`, it unwraps a single-KEY Hash to its first `[key,
#   value]` pair the same way.
# * `NestedRecord#result` then re-symbolizes an unwrapped Hash's keys.
# * The resource attribute type is `Array.of(Hash)`, so when dry-struct
#   coerces the single Hash back into an Array it calls `Array(hash)`, which
#   splays a Hash into `[[:key, value], ...]` pairs.
#
# Net effect: a saved `[{a: 1, b: 2}]` reads back as `[[:a, 1], [:b, 2]]`,
# a saved `[{a: 1}]` reads back as `["a", 1]`, and a saved
# `[{a: 1}, {a: 2}]` reads back as `[[:a, 1], [:a, 2]]`.
#
# Hyrax main carries the same defense (Hyrax::CompoundNormalization, included
# in Hyrax::Work), but its class-level `.new` hook resolves the compound list
# from the CLASS schema, which is empty in flexible mode - so on reload the
# splayed value reaches dry-struct's coercion unfixed and raises. This concern
# stays as the flex-mode gap-filler until that is fixed upstream; the list is
# derived from the M3 profile so any new compound is covered automatically.
#
# We intercept at three layers:
#   - `klass.new(attrs)` (class-level, via singleton_class.prepend) so
#     dry-struct's strict type coercion never sees a splayed pair array
#     during reload from the persister.
#   - `set_value` (instance, write path).
#   - per-compound reader (instance, read path).
module EnactCompoundNormalization
  # The knapsack M3 profile, read from disk rather than the FlexibleSchema DB
  # record because COMPOUND_ATTRS is consumed at class-load (the readers below
  # are generated with `define_method`), before a database is guaranteed to be
  # available (e.g. assets:precompile eager-load).
  PROFILE_PATH = HykuKnapsack::Engine.root.join('config', 'metadata_profiles', 'm3_profile.yaml')

  COMPOUND_ATTRS = YAML.safe_load(::File.read(PROFILE_PATH))['properties']
                       .select { |_name, config| config.is_a?(::Hash) && config['type'] == 'hash' }
                       .keys.map(&:to_sym).freeze

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
    # In flexible mode the dry-struct reader for an attribute is not always in
    # this wrapper's super chain (the singleton schema is applied per load), so
    # fall back to the raw attribute read rather than assuming super exists.
    define_method(attr) do
      value = defined?(super) ? super() : self[attr]
      EnactCompoundNormalization.normalize_compound(value)
    end
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

  # Pair-array reconstruction. A pair array has two possible origins and the
  # right reconstruction differs:
  #
  # * ONE multi-key entry, splayed: `[[:a, 1], [:b, 2]]` -> `[{a: 1, b: 2}]`.
  # * SEVERAL single-key entries, each unwrapped to its first pair:
  #   `[[:a, 1], [:a, 2]]` -> `[{a: 1}, {a: 2}]`.
  #
  # Duplicate keys can only come from the second origin (a single splayed
  # entry cannot repeat a key), so rebuild one entry per pair; merging them
  # (`Hash[arr]`) silently keeps only the last value. Distinct keys are
  # genuinely ambiguous between the two origins; we keep the single-entry
  # reading, which matches the far more common shape. Returns nil if the
  # input doesn't look like a pair array.
  def self.collapse_pair_array(arr)
    return nil if arr.empty?
    return nil unless arr.all? { |e| pair?(e) }
    return arr.map { |pair| ::Hash[[pair]] } if arr.map(&:first).map(&:to_s).uniq.length < arr.length
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
