# frozen_string_literal: true

require 'rails_helper'

# The User side of the 1:1 research-profile link. The association is deliberately
# NOT dependent: :destroy — see the "survives" example below.
RSpec.describe UserDecorator do
  let(:user) { FactoryBot.create(:user) }

  describe '#enact_contributor' do
    it 'returns the linked profile' do
      contributor = Enact::Contributor.create!(display_name: 'Ada', user:)
      expect(user.reload.enact_contributor).to eq(contributor)
    end

    it 'is nil when the user has no profile' do
      expect(user.enact_contributor).to be_nil
    end
  end

  describe '#research_profile?' do
    it 'is true once a profile is linked' do
      Enact::Contributor.create!(display_name: 'Ada', user:)
      expect(user.reload).to be_research_profile
    end

    it 'is false without one' do
      expect(user).not_to be_research_profile
    end
  end

  # Profiles are curated repository metadata, not user-owned data: they credit
  # works and outlive the account.
  it 'leaves the profile intact when the user is deleted' do
    contributor = Enact::Contributor.create!(display_name: 'Ada', user:)
    user.destroy
    expect(Enact::Contributor.exists?(contributor.id)).to be(true)
  end

  # Drives the admin worklist query.
  describe '.where.missing(:enact_contributor)' do
    it 'excludes users who already have a profile' do
      linked = FactoryBot.create(:user)
      Enact::Contributor.create!(display_name: 'Ada', user: linked)
      unlinked = FactoryBot.create(:user)

      result = User.where.missing(:enact_contributor)
      expect(result).to include(unlinked)
      expect(result).not_to include(linked)
    end

    it 'excludes guest users' do
      guest = User.create!(email: "guest-#{SecureRandom.hex(4)}@example.com",
                           password: 'a password', guest: true)
      expect(User.where.missing(:enact_contributor)).not_to include(guest)
    end
  end
end
