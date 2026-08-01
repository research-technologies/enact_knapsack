# frozen_string_literal: true

require 'rails_helper'

# Who may curate a research profile, and who may manage the links between
# profiles and accounts.
RSpec.describe Ability do
  subject(:ability) { described_class.new(user) }

  let(:unclaimed) { Enact::Contributor.create!(display_name: 'Ada Lovelace') }

  context 'as an admin' do
    let(:user) { FactoryBot.create(:admin) }

    it 'may edit any profile' do
      expect(ability.can?(:edit, unclaimed)).to be true
      expect(ability.can?(:edit, Enact::Contributor.create!(display_name: 'Grace', user: FactoryBot.create(:user)))).to be true
    end

    it 'may manage profile links' do
      expect(ability.can?(:manage, :research_profile_links)).to be true
    end
  end

  context 'as the user who claimed a profile' do
    let(:user) { FactoryBot.create(:user) }
    let!(:own) { Enact::Contributor.create!(display_name: 'Ada Lovelace', user:) }

    it 'may edit their own profile' do
      expect(ability.can?(:edit, own)).to be true
    end

    it 'may not edit someone else’s' do
      other = Enact::Contributor.create!(display_name: 'Grace', user: FactoryBot.create(:user))
      expect(ability.can?(:edit, other)).to be false
    end

    it 'may not edit an unclaimed profile' do
      expect(ability.can?(:edit, unclaimed)).to be false
    end

    it 'may not manage profile links' do
      expect(ability.can?(:manage, :research_profile_links)).to be false
    end
  end

  context 'as a signed-in user with no profile' do
    let(:user) { FactoryBot.create(:user) }

    it 'may not edit a profile' do
      expect(ability.can?(:edit, unclaimed)).to be false
    end
  end

  context 'as an anonymous visitor' do
    let(:user) { nil }

    it 'may not edit a profile' do
      expect(ability.can?(:edit, unclaimed)).to be false
    end

    it 'may not edit a claimed profile' do
      claimed = Enact::Contributor.create!(display_name: 'Grace', user: FactoryBot.create(:user))
      expect(ability.can?(:edit, claimed)).to be false
    end
  end
end
