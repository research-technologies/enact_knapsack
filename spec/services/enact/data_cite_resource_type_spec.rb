# frozen_string_literal: true

require 'rails_helper'

# Maps a work's item_subtype onto DataCite's resourceTypeGeneral: first by the
# DataCite schema reference already present in some subtype authority terms'
# own `id`s, then by a human-curated fallback keyed on the term's label, then
# a per-work-class default (see config/initializers/hyrax_pid.rb).
RSpec.describe Enact::DataCiteResourceType do
  def work_double(item_subtype:, class_name: 'PortfolioArtefact')
    double('Work', item_subtype:, class: double('Class', name: class_name)) # rubocop:disable RSpec/VerifiedDoubles
  end

  describe '.general_for' do
    it 'maps a subtype whose id references the DataCite schema directly' do
      work = work_double(item_subtype: 'https://datacite-metadata-schema.readthedocs.io/en/4.5/appendices/appendix-1/resourceTypeGeneral/#physicalobject')
      expect(described_class.general_for(work)).to eq('PhysicalObject')
    end

    it 'tolerates a different schema version segment in the id' do
      work = work_double(item_subtype: 'https://datacite-metadata-schema.readthedocs.io/en/4.7/appendices/appendix-1/resourceTypeGeneral/#dataset')
      expect(described_class.general_for(work)).to eq('Dataset')
    end

    it 'unwraps a single-element Array (Valkyrie multi-value storage)' do
      work = work_double(item_subtype: ['https://datacite-metadata-schema.readthedocs.io/en/4.5/appendices/appendix-1/resourceTypeGeneral/#sound'])
      expect(described_class.general_for(work)).to eq('Sound')
    end

    context 'when the subtype has no direct DataCite id, but a label-based fallback matches' do
      it 'uses the longest matching FALLBACK_GENERAL_BY_PREFIX entry' do
        work = work_double(item_subtype: 'http://vocab.getty.edu/page/aat/300047896')
        allow(Enact::ItemSubtypeLabels).to receive(:label_for).with(work.item_subtype).and_return('Physical Object - Installation')

        expect(described_class.general_for(work)).to eq('PhysicalObject')
      end

      it "prefers a more specific prefix (e.g. 'Working paper') over a shorter one that doesn't apply here" do
        work = work_double(item_subtype: 'https://vocabularies.coar-repositories.org/resource_types/c_8042/', class_name: 'PortfolioLiterature')
        allow(Enact::ItemSubtypeLabels).to receive(:label_for).with(work.item_subtype).and_return('Working paper')

        expect(described_class.general_for(work)).to eq('Preprint')
      end
    end

    context 'when nothing matches but the work class has a CLASS_DEFAULT_GENERAL' do
      it "falls back to the work class's default (e.g. PortfolioEvent -> Event)" do
        work = work_double(item_subtype: 'http://vocab.getty.edu/page/aat/300054760', class_name: 'PortfolioEvent')
        allow(Enact::ItemSubtypeLabels).to receive(:label_for).with(work.item_subtype).and_return('Competition / open call')

        expect(described_class.general_for(work)).to eq('Event')
      end
    end

    it 'falls back to "Other" for a PortfolioArtefact subtype with no id reference, label match, or class default (e.g. Design)' do
      work = work_double(item_subtype: 'http://vocab.getty.edu/page/aat/300054181')
      allow(Enact::ItemSubtypeLabels).to receive(:label_for).with(work.item_subtype).and_return('Design - GraphicDesign')

      expect(described_class.general_for(work)).to eq('Other')
    end

    it 'falls back to "Other" when item_subtype is blank and the work class has no default' do
      work = work_double(item_subtype: nil)
      expect(described_class.general_for(work)).to eq('Other')
    end
  end

  describe '.general_for_subtype_id' do
    it 'returns nil for an id with no DataCite reference, so callers can distinguish "unmapped" from "Other"' do
      expect(described_class.general_for_subtype_id('https://schema.org/Painting')).to be_nil
    end
  end

  describe '.general_for_subtype_label' do
    it "returns nil when the id doesn't resolve to a known term (Enact::ItemSubtypeLabels hands the id back unchanged)" do
      id = 'https://example.com/unknown-term'
      allow(Enact::ItemSubtypeLabels).to receive(:label_for).with(id).and_return(id)

      expect(described_class.general_for_subtype_label(id)).to be_nil
    end
  end
end
