# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Hyrax::CompoundFieldsHelperDecorator, type: :helper do
  let(:presenter_class) do
    Class.new do
      attr_accessor :id, :relationships

      def initialize(id:, relationships: nil)
        @id = id
        @relationships = relationships
      end

      def try(method)
        send(method) if respond_to?(method)
      end
    end
  end

  before do
    allow(helper).to receive(:render).and_call_original
    allow(helper).to receive(:compound_schema_for).and_return(
      instance_double('Schema', card_compound_names: [:relationships])
    )
  end

  describe '#render_compound_cards' do
    it 'appends exactly one map modal when the map has something to draw' do
      presenter = presenter_class.new(id: 'work-id', relationships: [{ item: 'other' }])
      allow(helper).to receive(:enact_relationship_map?).with(presenter).and_return(true)
      allow(helper).to receive(:render).with('hyrax/compounds/compound_card', any_args).and_return('card'.html_safe)
      allow(helper).to receive(:render).with('enact/shared/map_modal').once.and_return('modal'.html_safe)

      helper.render_compound_cards(presenter)

      expect(helper).to have_received(:render).with('enact/shared/map_modal').once
    end

    # Keyed off the same gate as the button, so a card with no button carries no modal
    # (issue #161).
    it 'does not render the map modal when the map would open empty' do
      presenter = presenter_class.new(id: 'work-id', relationships: [{ item: 'other' }])
      allow(helper).to receive(:enact_relationship_map?).with(presenter).and_return(false)
      allow(helper).to receive(:render).with('hyrax/compounds/compound_card', any_args).and_return('card'.html_safe)
      allow(helper).to receive(:render).with('enact/shared/map_modal')

      helper.render_compound_cards(presenter)

      expect(helper).not_to have_received(:render).with('enact/shared/map_modal')
    end

    it 'does not render the map modal when no relationships card is shown' do
      presenter = presenter_class.new(id: 'work-id', relationships: nil)
      allow(Hyrax::SolrService).to receive(:count).and_return(0)
      allow(helper).to receive(:render).with('enact/shared/map_modal')

      helper.render_compound_cards(presenter)

      expect(helper).not_to have_received(:render).with('enact/shared/map_modal')
    end
  end
end
