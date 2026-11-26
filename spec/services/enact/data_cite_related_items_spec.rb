# frozen_string_literal: true

require 'rails_helper'

# Supplies hyrax-pid's DataCite :related_items field_mapping value (see
# config/initializers/hyrax_pid.rb) from a work's `relationships` compound,
# via relationship_types.yml's own `datacite:` key per term.
RSpec.describe Enact::DataCiteRelatedItems do
  def work_double(relationships:)
    double('Work', relationships:) # rubocop:disable RSpec/VerifiedDoubles
  end

  describe '.related_items_for' do
    it 'maps a controlled relationship type to its DataCite relationType, for an external URL target' do
      work = work_double(relationships: [{ item: 'https://example.org/related-thing', type: 'iscitedby' }])

      expect(described_class.related_items_for(work)).to eq(
        [
          { relationType: 'IsCitedBy', relatedItemType: 'Other', relatedItemIdentifier: 'https://example.org/related-thing', relatedItemIdentifierType: 'URL' }
        ]
      )
    end

    it 'falls back to "Other" for an Enact-local term with no datacite: mapping' do
      work = work_double(relationships: [{ item: 'https://example.org/x', type: 'is-realisation-of' }])

      expect(described_class.related_items_for(work).first[:relationType]).to eq('Other')
    end

    it 'falls back to "Other" for a free-text "other" edge with no controlled type' do
      work = work_double(relationships: [{ item: 'https://example.org/x', type_other: 'Some free-text relation' }])

      expect(described_class.related_items_for(work).first[:relationType]).to eq('Other')
    end

    it 'skips an entry with neither a controlled type nor free-text type_other' do
      work = work_double(relationships: [{ item: 'https://example.org/x' }])

      expect(described_class.related_items_for(work)).to eq([])
    end

    it 'skips an entry with a type but no item target' do
      work = work_double(relationships: [{ type: 'cites' }])

      expect(described_class.related_items_for(work)).to eq([])
    end

    it 'tolerates string-keyed entries' do
      work = work_double(relationships: [{ 'item' => 'https://example.org/x', 'type' => 'cites' }])

      expect(described_class.related_items_for(work).first[:relationType]).to eq('Cites')
    end

    context 'with an internal target that resolves to a work' do
      let(:target) { double('Work', item_subtype: 'https://datacite-metadata-schema.readthedocs.io/en/4.5/appendices/appendix-1/resourceTypeGeneral/#dataset', doi: ['10.1234/abc']) } # rubocop:disable RSpec/VerifiedDoubles

      it "uses the target's own DataCite resourceType and DOI, instead of defaulting to Other/omitting the identifier" do
        work = work_double(relationships: [{ item: 'target-id', type: 'cites' }])
        allow(Hyrax::CompoundWorkResolver).to receive(:url?).with('target-id').and_return(false)
        allow(Hyrax).to receive(:query_service).and_return(double('QueryService', find_by: target)) # rubocop:disable RSpec/VerifiedDoubles

        expect(described_class.related_items_for(work)).to eq(
          [{ relationType: 'Cites', relatedItemType: 'Dataset', relatedItemIdentifier: '10.1234/abc', relatedItemIdentifierType: 'DOI' }]
        )
      end
    end

    context 'with an internal target id that no longer resolves' do
      it 'defaults relatedItemType to "Other" and omits relatedItemIdentifier, rather than raising' do
        work = work_double(relationships: [{ item: 'missing-id', type: 'cites' }])
        allow(Hyrax::CompoundWorkResolver).to receive(:url?).with('missing-id').and_return(false)
        allow(Hyrax).to receive(:query_service).and_return(double('QueryService').tap { |q| allow(q).to receive(:find_by).and_raise(Hyrax::ObjectNotFoundError) }) # rubocop:disable RSpec/VerifiedDoubles

        expect(described_class.related_items_for(work)).to eq([{ relationType: 'Cites', relatedItemType: 'Other' }])
      end
    end

    it 'returns [] when the compound is empty' do
      expect(described_class.related_items_for(work_double(relationships: []))).to eq([])
    end
  end
end
