# frozen_string_literal: true

require 'rails_helper'

# Disables User Collection creation for everyone, even when the collection type
# would allow it; management and Admin Sets stay intact (#94).
RSpec.describe Ability do
  subject(:ability) { described_class.new(user) }

  let(:collection_class) { Hyrax.config.collection_class }

  shared_examples 'cannot create user collections' do
    it 'cannot create user collections' do
      expect(ability.can?(:create, collection_class)).to be false
      expect(ability.can?(:create_any, collection_class)).to be false
    end
  end

  context 'as an admin' do
    let(:user) { FactoryBot.create(:user, roles: [:admin]) }

    include_examples 'cannot create user collections'

    it 'still retains management of existing collections' do
      expect(ability.can?(:manage_any, collection_class)).to be true
    end
  end

  context 'as a non-admin whose collection type would grant creation' do
    let(:user) { FactoryBot.create(:user) }

    before do
      # Simulate a tenant whose collection type still grants create (staging leak).
      allow(Hyrax::CollectionTypes::PermissionsService)
        .to receive(:can_create_any_collection_type?).and_return(true)
    end

    include_examples 'cannot create user collections'
  end
end
