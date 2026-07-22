# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Hyrax::MenuPresenter do
  subject(:presenter) { described_class.new(double(controller:)) }

  describe '#user_activity_section?' do
    context 'on the job statuses page' do
      let(:controller) { Hyrax::Dashboard::JobStatusesController.new }

      it 'keeps the Your activity section open' do
        expect(presenter.user_activity_section?).to be true
      end
    end

    context 'on an unrelated page' do
      let(:controller) { Hyrax::HomepageController.new }

      it 'leaves the Your activity section closed' do
        expect(presenter.user_activity_section?).to be false
      end
    end
  end
end
