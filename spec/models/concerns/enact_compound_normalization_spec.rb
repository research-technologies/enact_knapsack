# frozen_string_literal: true

require 'rails_helper'

# Guards the Valkyrie/Postgres single-element-array splay (see the concern's
# header). `relationships` (added by PR #32) is the regression case: it is a
# repeatable `type: hash` compound that was NOT in the old hand-maintained
# list, so before this fix a one-row relationship splayed into pair arrays on
# reload. The list is now derived from the M3 profile, so it is covered.
RSpec.describe EnactCompoundNormalization, :clean_repo do
  describe '.COMPOUND_ATTRS (derived from the M3 profile)' do
    it 'covers every type: hash compound in the profile, not a hand-listed subset' do
      profile = YAML.safe_load(File.read(described_class::PROFILE_PATH))
      declared = profile['properties'].select do |_name, defn|
        defn.is_a?(Hash) && !defn.key?('subproperty_of') &&
          (defn['type'] == 'hash' || defn['range'].to_s.include?('#hash'))
      end.keys.map(&:to_sym)

      expect(described_class::COMPOUND_ATTRS).to match_array(declared)
      expect(described_class::COMPOUND_ATTRS).to include(:relationships)
    end
  end

  describe 'single-row relationships round-trip' do
    let(:entry) do
      { 'relationship_item' => 'abc123',
        'relationship_type' => 'source-of',
        'relationship_position' => '1',
        'relationship_note' => 'The model is the source for the export' }
    end

    let(:saved) do
      Hyrax.persister.save(resource: Portfolio.new(title: ['Source work'], relationships: [entry]))
    end

    # Reloading from the persister is the path that triggers the splay: the
    # Postgres value mapper unwraps the one-element array, and dry-struct's
    # `Array(hash)` coercion would splay it into `[[:k, v], ...]` without the
    # normalization the concern applies.
    subject(:relationships) { Hyrax.query_service.find_by(id: saved.id).relationships }

    it 'reads back as an array of one hash, not a splayed pair array' do
      expect(relationships.size).to eq(1)
      expect(relationships.first).to be_a(Hash)
      expect(relationships.first).to include(
        'relationship_item' => 'abc123',
        'relationship_type' => 'source-of',
        'relationship_position' => '1'
      )
    end
  end
end
