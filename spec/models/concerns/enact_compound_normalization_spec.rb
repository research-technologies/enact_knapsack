# frozen_string_literal: true

require 'rails_helper'

# Guards the Valkyrie/Postgres read-path mangling of `type: hash` compounds
# (see the concern's header). Hyrax main's own Hyrax::CompoundNormalization
# covers part of this, but its class-level `.new` hook resolves the compound
# list from the class schema - empty in flexible mode - so this concern remains
# the flex-mode defense. These examples round-trip through the real persister,
# the path that triggers the mangling.
RSpec.describe EnactCompoundNormalization, :clean_repo do
  describe '.COMPOUND_ATTRS (derived from the M3 profile)' do
    it 'covers every type: hash compound, not a hand-maintained subset' do
      declared = YAML.safe_load(File.read(described_class::PROFILE_PATH))['properties']
                     .select { |_name, config| config.is_a?(Hash) && config['type'] == 'hash' }
                     .keys.map(&:to_sym)

      expect(described_class::COMPOUND_ATTRS).to match_array(declared)
      expect(described_class::COMPOUND_ATTRS).to include(:relationships)
    end
  end

  def reload(attrs)
    saved = Hyrax.persister.save(resource: Portfolio.new(title: ['round-trip'], **attrs))
    Hyrax.query_service.find_by(id: saved.id).public_send(attrs.keys.first)
  end

  describe 'single-entry round-trips' do
    it 'multi-key entry survives (the splay case)' do
      value = reload(relationships: [{ 'item' => 'abc', 'type' => 'source-of', 'note' => 'n' }])
      expect(value).to eq([{ 'item' => 'abc', 'type' => 'source-of', 'note' => 'n' }])
    end

    it 'single-key entry survives (the flat-pair case)' do
      value = reload(identifiers: [{ 'value' => 'doi:10.1/x' }])
      expect(value).to eq([{ 'value' => 'doi:10.1/x' }])
    end

    it 'single-key relationships entry survives (was unprotected by the old hardcoded list)' do
      value = reload(relationships: [{ 'item' => 'abc' }])
      expect(value).to eq([{ 'item' => 'abc' }])
    end
  end

  describe 'multi-entry round-trips' do
    it 'several single-field entries with the same key all survive (was last-wins data loss)' do
      value = reload(contributors: [{ 'name' => 'A' }, { 'name' => 'B' }, { 'name' => 'C' }])
      expect(value).to eq([{ 'name' => 'A' }, { 'name' => 'B' }, { 'name' => 'C' }])
    end

    it 'several multi-key entries survive (control)' do
      value = reload(contributors: [{ 'name' => 'A', 'given_name' => 'a' },
                                    { 'name' => 'B', 'given_name' => 'b' }])
      expect(value.length).to eq(2)
    end

    # KNOWN LIMITATION: N single-field entries with DISTINCT keys arrive at the
    # normalizer as a pair array indistinguishable from ONE splayed multi-key
    # entry; we keep the single-entry reading. Fixing this requires acting in
    # the orm converter, where the original JSONB shape is still known - that
    # belongs in Hyrax/Valkyrie, not here.
  end
end
