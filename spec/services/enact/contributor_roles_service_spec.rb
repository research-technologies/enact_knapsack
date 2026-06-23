# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Enact::ContributorRolesService do
  describe '.codes' do
    it 'returns every role code, CRediT terms before practice terms' do
      expect(described_class.codes).to include('conceptualization', 'data-curation', 'choreographer')
      credit_last = described_class.codes.index('writing-review-editing')
      practice_first = described_class.codes.index('choreographer')
      expect(credit_last).to be < practice_first
    end
  end

  describe '.credit_uri' do
    it 'returns the canonical CRediT URI for a CRediT role' do
      expect(described_class.credit_uri('data-curation'))
        .to eq('https://credit.niso.org/contributor-roles/data-curation/')
    end

    it 'is nil for a practice role (CRediT has no URI for it)' do
      expect(described_class.credit_uri('choreographer')).to be_nil
    end
  end

  describe '.datacite' do
    it 'maps a CRediT role to its DataCite contributorType' do
      expect(described_class.datacite('data-curation')).to eq('DataCurator')
    end

    it 'falls back to "Other" for a practice role' do
      expect(described_class.datacite('choreographer')).to eq('Other')
    end

    it 'falls back to "Other" for an unknown code so a minter always has a valid value' do
      expect(described_class.datacite('nonsense-role')).to eq('Other')
    end
  end

  describe '.marc' do
    it 'returns a MARC relator code where one fits a practice role' do
      expect(described_class.marc('dancer')).to eq('dnc')
    end

    it 'is nil where no relator is mapped' do
      expect(described_class.marc('data-curation')).to be_nil
    end
  end

  describe '.label' do
    it 'resolves the human label from the authority term' do
      expect(described_class.label('data-curation')).to eq('Data curation')
    end

    it 'falls back to the code itself for an unknown/legacy value (AuthorityService semantics)' do
      expect(described_class.label('some-legacy-code')).to eq('some-legacy-code')
    end
  end

  # Guard: the m3 `contributor_role` subproperty must be backed by the same
  # `contributor_roles` authority this service reads, so the deposit vocabulary
  # and the interop lookups (CRediT URI / DataCite contributorType / MARC) are
  # one source of truth and cannot drift.
  describe 'm3 profile <-> authority binding' do
    let(:profile) do
      path = HykuKnapsack::Engine.root.join('config', 'metadata_profiles', 'm3_profile.yaml')
      YAML.load_file(path)
    end

    it 'declares the contributor_roles authority on contributor_role' do
      expect(profile.dig('properties', 'contributor_role', 'authority'))
        .to eq('contributor_roles')
    end

    it 'offers no inline values (the authority is the source of truth)' do
      expect(profile.dig('properties', 'contributor_role', 'values')).to be_nil
    end
  end
end
