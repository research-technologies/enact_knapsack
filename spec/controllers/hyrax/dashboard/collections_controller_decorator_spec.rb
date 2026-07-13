# frozen_string_literal: true

require 'rails_helper'

# Covers the knapsack guard that blocks non-admins from the User Collection
# create form/action even when the collection type would otherwise permit it
# (e.g. typing /dashboard/collections/new directly). See
# research-technologies/enact_knapsack#94.
RSpec.describe Hyrax::Dashboard::CollectionsController, type: :controller do
  routes { Hyrax::Engine.routes }

  let(:user) { FactoryBot.create(:user) }
  let(:ability) { ::Ability.new(user) }

  before do
    sign_in user
    allow(controller).to receive(:current_ability).and_return(ability)
    # Gate only on the admin check; let every other permission resolve normally.
    allow(ability).to receive(:can?).and_call_original
    allow(ability).to receive(:can?).with(:read, :admin_dashboard).and_return(admin)
  end

  describe '#require_admin_to_create_collection' do
    context 'as an admin' do
      let(:admin) { true }

      it 'permits collection creation' do
        expect { controller.send(:require_admin_to_create_collection) }.not_to raise_error
      end
    end

    context 'as a non-admin' do
      let(:admin) { false }

      it 'raises AccessDenied even if the collection type would allow it' do
        expect { controller.send(:require_admin_to_create_collection) }
          .to raise_error(CanCan::AccessDenied)
      end
    end
  end

  describe 'GET #new' do
    context 'as a non-admin' do
      let(:admin) { false }

      it 'is denied and does not render the create form' do
        get :new
        expect(response).to have_http_status(:redirect)
        expect(response).not_to render_template(:new)
      end
    end
  end
end
