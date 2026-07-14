# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Hyrax::PermissionBadgeDecorator do
  describe '#text' do
    context 'with authenticated visibility' do
      let(:visibility) { Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_AUTHENTICATED }

      it 'renders the label from the visibility locale, not Hyrax::Institution.name' do
        allow(Hyrax::Institution).to receive(:name).and_return('SHOULD-NOT-APPEAR')
        badge = Hyrax::PermissionBadge.new(visibility).render

        expect(badge).to include(I18n.t('hyrax.visibility.authenticated.text'))
        expect(badge).not_to include('SHOULD-NOT-APPEAR')
      end
    end

    context 'with any other visibility' do
      let(:visibility) { Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC }

      it 'defers to super' do
        expect(Hyrax::PermissionBadge.new(visibility).render)
          .to include(I18n.t('hyrax.visibility.open.text'))
      end
    end
  end
end
