# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HykuKnapsack::ReseedValidChildConcerns do
  let(:portfolio_types) do
    [Portfolio, PortfolioArtefact, PortfolioEvent, PortfolioLiterature, PortfolioItemCollection]
  end
  # Portfolio bars itself as a child (see Portfolio.valid_child_concern?), so
  # the seeded child list is the registered concerns minus Portfolio.
  let(:expected) { (Hyrax.config.curation_concerns - [Portfolio]).map(&:to_s) }

  # Restore whatever the app booted with, so mutating the class attribute in an
  # example cannot leak into others.
  around do |example|
    saved = portfolio_types.index_with(&:valid_child_concerns)
    example.run
    saved.each { |klass, value| klass.valid_child_concerns = value }
  end

  describe '.call' do
    it 'reflects the fully-registered curation concerns on every Portfolio type' do
      # Simulate the stale snapshot an eager-load boot produces: the Hyku
      # default work types, registered before Enact's deferred registration.
      portfolio_types.each { |klass| klass.valid_child_concerns = %w[GenericWork Image Etd Oer] }

      described_class.call

      portfolio_types.each do |klass|
        expect(klass.valid_child_concerns.map(&:to_s)).to match_array(expected)
        expect(klass.valid_child_concerns.map(&:to_s)).not_to include('GenericWork', 'Image', 'Etd', 'Oer')
      end
    end

    it 'never lists Portfolio as a valid child of any type, including itself' do
      described_class.call

      portfolio_types.each do |klass|
        expect(klass.valid_child_concerns).not_to include(Portfolio)
      end
    end
  end

  it 'leaves the class attribute matching the registered concerns after boot' do
    # The initializer's boot-pass call already re-seeded; values are correct
    # without re-invoking the service.
    portfolio_types.each do |klass|
      expect(klass.valid_child_concerns.map(&:to_s)).to match_array(expected)
    end
  end
end
