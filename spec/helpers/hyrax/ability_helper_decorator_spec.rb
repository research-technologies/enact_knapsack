# frozen_string_literal: true

require 'rails_helper'

# Exercises Hyrax::AbilityHelperDecorator, which is prepended to
# Hyrax::AbilityHelper (so it lives in the helper's ancestry here).
RSpec.describe Hyrax::AbilityHelper, type: :helper do
  describe '#visibility_options' do
    subject(:labels) { helper.visibility_options(nil).to_h.invert }

    it 'labels authenticated visibility from the visibility locale, not the institution name' do
      value = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_AUTHENTICATED
      expect(labels[value]).to eq(I18n.t('hyrax.visibility.authenticated.text'))
    end

    it 'defers to super for other visibilities' do
      value = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC
      expect(labels[value]).to eq(I18n.t('hyrax.visibility.open.text'))
    end
  end
end
