# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Enact::MapModalHelper, type: :helper do
  describe '#enact_map_trigger' do
    subject(:html) { helper.enact_map_trigger('Relationship map', '/relationship-map?focus=abc123') }

    it 'emits data-map-url and data-map-title for the modal script' do
      expect(html).to include('data-map-url="/relationship-map?focus=abc123"')
      expect(html).to include('data-map-title="Relationship map"')
    end

    it 'sets aria-haspopup and aria-controls for the dialog' do
      expect(html).to include('aria-haspopup="dialog"')
      expect(html).to include('aria-controls="enactMapModal"')
    end

    it 'keeps href as a non-JS fallback to the standalone map page' do
      expect(html).to include('href="/relationship-map?focus=abc123"')
    end

    it 'allows callers to override the button class' do
      custom = helper.enact_map_trigger('Map', '/people-map', html_class: 'btn btn-primary')
      expect(custom).to include('class="btn btn-primary"')
    end
  end
end
