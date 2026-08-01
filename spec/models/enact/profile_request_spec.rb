# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Enact::ProfileRequest do
  let(:user) { FactoryBot.create(:user) }
  let(:admin) { FactoryBot.create(:admin) }

  it 'is pending when created' do
    request = described_class.create!(user:)
    expect(request).to be_pending
    expect(described_class.pending).to include(request)
  end

  it 'requires a user' do
    expect(described_class.new).not_to be_valid
  end

  it 'optionally targets a contributor to claim' do
    contributor = Enact::Contributor.create!(display_name: 'Ada')
    expect(described_class.create!(user:, contributor:).contributor).to eq(contributor)
    expect(described_class.new(user: FactoryBot.create(:user)).contributor).to be_nil
  end

  describe 'one open request per user' do
    it 'rejects a second pending request' do
      described_class.create!(user:)
      duplicate = described_class.new(user:)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:user_id]).to be_present
    end

    it 'enforces it in the database' do
      described_class.create!(user:)
      expect { described_class.new(user:).save!(validate: false) }
        .to raise_error(ActiveRecord::RecordNotUnique)
    end

    it 'allows a new request after an earlier one was declined' do
      described_class.create!(user:).decline!(by: admin, note: 'Not verified.')
      expect { described_class.create!(user:) }.not_to raise_error
      expect(described_class.where(user:).count).to eq(2)
    end

    it 'allows a new request after an earlier one was approved' do
      described_class.create!(user:).approve!(by: admin)
      expect { described_class.create!(user:) }.not_to raise_error
    end
  end

  describe 'review' do
    it 'records the reviewer and timestamp on approval' do
      request = described_class.create!(user:)
      request.approve!(by: admin)
      expect(request.reload).to be_approved
      expect(request.reviewed_by).to eq(admin)
      expect(request.reviewed_at).to be_present
    end

    it 'records the reviewer, timestamp and reason on decline' do
      request = described_class.create!(user:)
      request.decline!(by: admin, note: 'Could not verify identity.')
      expect(request.reload).to be_declined
      expect(request.reviewed_by).to eq(admin)
      expect(request.reviewed_at).to be_present
      expect(request.review_note).to eq('Could not verify identity.')
    end

    it 'keeps the requesters note separate from the reviewers reason' do
      request = described_class.create!(user:, note: 'I deposit under Ada L.')
      request.decline!(by: admin, note: 'Could not verify identity.')
      expect(request.reload.note).to eq('I deposit under Ada L.')
      expect(request.review_note).to eq('Could not verify identity.')
    end

    it 'refuses to decline without a reason' do
      request = described_class.create!(user:)
      expect { request.decline!(by: admin, note: '  ') }.to raise_error(ArgumentError)
      expect(request.reload).to be_pending
    end

    it 'keeps declined requests as an audit trail' do
      request = described_class.create!(user:)
      request.decline!(by: admin, note: 'Not verified.')
      expect(described_class.exists?(request.id)).to be(true)
      expect(described_class.pending).not_to include(request)
    end
  end

  it 'rejects a claim naming a contributor that does not exist' do
    request = described_class.new(user:, contributor_id: 999_999)
    expect(request).not_to be_valid
    expect(request.errors[:contributor]).to be_present
  end

  it 'rejects a claim on an organization' do
    org = Enact::Contributor.create!(display_name: 'Acme Lab', agent_type: 'organization')
    request = described_class.new(user:, contributor: org)
    expect(request).not_to be_valid
    expect(request.errors[:contributor]).to be_present
  end

  it 'rejects a claim on an already-claimed contributor' do
    claimed = Enact::Contributor.create!(display_name: 'Ada', user: FactoryBot.create(:user))
    request = described_class.new(user:, contributor: claimed)
    expect(request).not_to be_valid
    expect(request.errors[:contributor]).to be_present
  end

  it 'rejects a request from a user who already has a profile' do
    Enact::Contributor.create!(display_name: 'Ada', user:)
    request = described_class.new(user:)
    expect(request).not_to be_valid
    expect(request.errors[:user]).to be_present
  end
end
