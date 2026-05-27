# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PortfolioForm do
  subject(:form) { described_class.new(Portfolio.new) }

  describe '.build_permitted_params' do
    it 'allows the *_attributes nested hash for every compound' do
      params = described_class.build_permitted_params
      described_class::COMPOUND_ATTRIBUTES.each do |key, attrs|
        entry = params.find { |p| p.is_a?(Hash) && p.key?(:"#{key}_attributes") }
        expect(entry).not_to be_nil, "missing permitted entry for #{key}_attributes"
        expect(entry[:"#{key}_attributes"]).to include(*attrs)
        expect(entry[:"#{key}_attributes"]).to include('_destroy')
      end
    end
  end

  describe 'compound populators' do
    it 'builds plain hashes from nested-attribute payloads and drops blank / destroyed rows' do
      fragment = {
        '0' => { 'given_name' => 'Avery', 'family_name' => 'Brooks', 'role_label' => 'composer' },
        '1' => { 'given_name' => 'Removed', '_destroy' => 'true' },
        '2' => { 'given_name' => '', 'family_name' => '' },
        '_marker' => { '_destroy' => '1' }
      }
      form.contributors_attributes_populator(fragment: fragment)
      expect(form.contributors).to eq([
                                        { 'given_name' => 'Avery',
                                          'family_name' => 'Brooks',
                                          'role_label' => 'composer' }
                                      ])
    end

    it 'orders rows by their numeric index' do
      fragment = {
        '10' => { 'value' => 'second' },
        '2' => { 'value' => 'first' }
      }
      form.identifiers_attributes_populator(fragment: fragment)
      expect(form.identifiers.map { |i| i['value'] }).to eq(%w[first second])
    end
  end
end
