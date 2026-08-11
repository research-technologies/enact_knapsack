# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EnactCatalogHelper do
  describe '#item_subtype_labels' do
    it 'labels subtypes drawn from different authorities in one call' do
      values = ['https://schema.org/Sculpture', 'https://schema.org/ChildrensEvent']

      expect(helper.item_subtype_labels(value: values))
        .to eq('Physical Object - Sculpture, Childrens Event')
    end

    it 'leaves an unknown value as-is' do
      expect(helper.item_subtype_labels(value: ['https://example.org/nope']))
        .to eq('https://example.org/nope')
    end

    it 'handles a missing value' do
      expect(helper.item_subtype_labels(value: nil)).to eq('')
    end
  end
end
