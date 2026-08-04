# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EnactHomeHelper, type: :helper do
  describe '#enact_card_blurb' do
    it 'prefers the description' do
      presenter = double('presenter', description: ['A commission for Dairy Primary School.'],
                                      context_statement: ['<p>Longer statement.</p>'])

      expect(helper.enact_card_blurb(presenter)).to eq('A commission for Dairy Primary School.')
    end

    it 'falls back to the context statement, which is where depositors actually write' do
      presenter = double('presenter', description: [], context_statement: ['<p>Six public artworks.</p>'])

      expect(helper.enact_card_blurb(presenter)).to eq('Six public artworks.')
    end

    it 'puts a space between paragraphs instead of running them together' do
      presenter = double('presenter', description: [],
                                      context_statement: ['<p>Six lighthouses.</p><p>The portfolio gathers.</p>'])

      expect(helper.enact_card_blurb(presenter)).to eq('Six lighthouses. The portfolio gathers.')
    end

    it 'truncates on a word boundary' do
      presenter = double('presenter', description: ["#{'word ' * 40}end"], context_statement: [])

      blurb = helper.enact_card_blurb(presenter, length: 30)

      expect(blurb.length).to be <= 30
      expect(blurb).to end_with('...')
    end

    it 'is nil when the work has neither' do
      presenter = double('presenter', description: [], context_statement: nil)

      expect(helper.enact_card_blurb(presenter)).to be_nil
    end
  end

  describe '#enact_thumbnail?' do
    it 'is false for Hyrax placeholder image, so the card shows the stripe instead' do
      presenter = double('presenter', thumbnail_path: Hyrax::ThumbnailPathService.default_image)

      expect(helper.enact_thumbnail?(presenter)).to be(false)
    end

    it 'is true for a real derivative' do
      presenter = double('presenter', thumbnail_path: '/downloads/abc123?file=thumbnail')

      expect(helper.enact_thumbnail?(presenter)).to be(true)
    end

    it 'is false when there is no path at all, rather than rendering a broken image' do
      presenter = double('presenter', thumbnail_path: nil)

      expect(helper.enact_thumbnail?(presenter)).to be(false)
    end
  end

  describe '#enact_contributor_summary' do
    let(:document) { double('document') }

    def credits(*labels)
      allow(Enact::WorkContributors).to receive(:new).with(document)
                                                     .and_return(double(credits: labels.map { |l| double(label: l) }))
    end

    it 'names one contributor' do
      credits('Bruce McLean')

      expect(helper.enact_contributor_summary(document)).to eq('Bruce McLean')
    end

    it 'names two' do
      credits('Bruce McLean', 'Jayne Osgood')

      expect(helper.enact_contributor_summary(document)).to eq('Bruce McLean and Jayne Osgood')
    end

    it 'counts the rest beyond two' do
      credits('Bruce McLean', 'Jayne Osgood', 'Neal White', 'Ama Boateng')

      expect(helper.enact_contributor_summary(document)).to eq('Bruce McLean; Jayne Osgood and 2 others')
    end

    it 'separates inverted names with a semicolon, so the commas inside them do not read as more people' do
      credits('Achebe, Ngozi', 'Okonkwo, Adaeze', 'White, Neal')

      expect(helper.enact_contributor_summary(document)).to eq('Achebe, Ngozi; Okonkwo, Adaeze and 1 other')
    end

    it 'is nil when the work credits nobody, so the card drops the line' do
      credits

      expect(helper.enact_contributor_summary(document)).to be_nil
    end
  end

  describe '#enact_featured_researcher?' do
    it 'is false for a blank content block, so the module hides' do
      assign(:featured_researcher, double(value: ''))

      expect(helper.enact_featured_researcher?).to be(false)
    end

    it 'is true once an admin has written one' do
      assign(:featured_researcher, double(value: '<p>Jayne Osgood</p>'))

      expect(helper.enact_featured_researcher?).to be(true)
    end
  end
end
