# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Enact::LicensesService do
  # A real SPDX term from config/authorities/licenses.yml, so the custom licenseId key
  # this service depends on is exercised rather than stubbed. authority.all normalises
  # entries to id/label/active and drops that key, which is why the service calls
  # authority.find instead.
  let(:cc_by) { 'https://spdx.org/licenses/CC-BY-4.0.html' }

  describe '.short_label' do
    it 'returns the SPDX code' do
      expect(described_class.short_label(cc_by)).to eq('CC-BY-4.0')
    end

    it 'falls back to the id when the term is unknown' do
      expect(described_class.short_label('not-a-licence')).to eq('not-a-licence')
    end
  end

  describe '#label' do
    it 'inherits the long term from Hyrax, rather than reimplementing it' do
      expect(described_class.new.label(cc_by)).to eq('Creative Commons Attribution 4.0 International')
    end
  end

  describe 'caching' do
    it 'parses the 109KB authority file once per id' do
      service = described_class.new
      expect(service.authority).to receive(:find).once.and_call_original

      2.times { service.short_label('https://spdx.org/licenses/0BSD.html') }
    end
  end
end
