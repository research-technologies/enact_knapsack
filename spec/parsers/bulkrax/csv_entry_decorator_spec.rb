# frozen_string_literal: true

require 'rails_helper'

# Bulkrax::CsvEntryDecorator resolves the `contributors` compound's
# `linked_record` member from the import CSV's human-readable name to the stored
# Enact::Contributor row id, after Bulkrax has assembled
# `contributors_attributes`. The find-vs-find-or-create branch is profile-driven
# (`contributor_ref`'s `creatable:`); a find-only miss is skipped and logged.
#
# Driven through a minimal host that prepends the decorator over a stub
# `build_metadata` (super) — exercises the real decorator against real
# contributor records and the real resolver, without a full Bulkrax import run.
RSpec.describe Bulkrax::CsvEntryDecorator do
  let(:host_class) do
    Class.new do
      attr_accessor :parsed_metadata

      def initialize(assembled)
        @parsed_metadata = { 'contributors_attributes' => assembled }
      end

      # Stand in for Bulkrax::CsvEntry#build_metadata, which the decorator calls
      # via super before post-processing.
      def build_metadata
        parsed_metadata
      end

      prepend Bulkrax::CsvEntryDecorator
    end
  end

  def build(assembled)
    entry = host_class.new(assembled)
    entry.build_metadata
    entry.parsed_metadata['contributors_attributes']
  end

  let!(:ada) { Enact::Contributor.create!(display_name: 'Ada Lovelace') }

  context 'when the contributor member is creatable (find-or-create)' do
    before { allow(described_class).to receive(:linked_record_member).and_return('creatable' => true) }

    it 'resolves an existing name to its row id' do
      result = build('0' => { 'contributor' => 'Ada Lovelace', 'role' => 'author', '_destroy' => 'false' })
      expect(result['0']['contributor']).to eq(ada.id.to_s)
      expect(result['0']['role']).to eq('author')
    end

    it 'creates a contributor on a miss and stores the new id' do
      result = nil
      expect do
        result = build('0' => { 'contributor' => 'Grace Hopper', '_destroy' => 'false' })
      end.to change(Enact::Contributor, :count).by(1)
      expect(result['0']['contributor']).to eq(Enact::Contributor.find_by(display_name: 'Grace Hopper').id.to_s)
    end

    it 'matches on ORCID when present, then strips the transient orcid carrier' do
      ada.update!(orcid: 'https://orcid.org/0000-0002-1825-0097')
      result = build('0' => { 'contributor' => 'A. Lovelace',
                              'orcid' => 'https://orcid.org/0000-0002-1825-0097', '_destroy' => 'false' })
      expect(result['0']['contributor']).to eq(ada.id.to_s)
      expect(result['0']).not_to have_key('orcid')
    end

    it 'reuses one row for the same name across entries' do
      result = build('0' => { 'contributor' => 'Ada Lovelace', '_destroy' => 'false' },
                     '1' => { 'contributor' => 'ada lovelace', '_destroy' => 'false' })
      expect(result['0']['contributor']).to eq(ada.id.to_s)
      expect(result['1']['contributor']).to eq(ada.id.to_s)
    end

    it 'drops an entry with a blank contributor name' do
      result = build('0' => { 'contributor' => '  ', 'role' => 'author', '_destroy' => 'false' })
      expect(result).to be_empty
    end

    describe 'record-attribute enrichment on create' do
      it 'sets agent_type, affiliations, and name_identifiers on a newly created contributor' do
        result = build('0' => {
                         'contributor' => 'Grace Hopper',
                         'agent_type' => 'organization',
                         'affiliation' => 'US Navy|Vassar College',
                         'name_identifier' => '0000000121032683;ISNI|https://ror.org/02mhbdp94;ROR',
                         '_destroy' => 'false'
                       })
        created = Enact::Contributor.find(result['0']['contributor'])
        expect(created.agent_type).to eq('organization')
        expect(created.affiliations).to eq(['US Navy', 'Vassar College'])
        expect(created.name_identifiers).to eq(
          [{ 'value' => '0000000121032683', 'scheme' => 'ISNI' },
           { 'value' => 'https://ror.org/02mhbdp94', 'scheme' => 'ROR' }]
        )
      end

      it 'drops every transient carrier from the final compound entry' do
        result = build('0' => {
                         'contributor' => 'Grace Hopper', 'agent_type' => 'person',
                         'affiliation' => 'US Navy', 'name_identifier' => '123;ISNI',
                         'role' => 'author', '_destroy' => 'false'
                       })
        expect(result['0'].keys).to contain_exactly('contributor', 'role', '_destroy')
      end

      it 'ignores enrichment when the contributor already exists (create-only)' do
        ada.update!(agent_type: 'person')
        build('0' => { 'contributor' => 'Ada Lovelace', 'agent_type' => 'organization',
                       'affiliation' => 'Somewhere', '_destroy' => 'false' })
        expect(ada.reload.agent_type).to eq('person')
        expect(ada.affiliations).to eq([])
      end
    end
  end

  context 'when the contributor member is find-only (creatable: false)' do
    before { allow(described_class).to receive(:linked_record_member).and_return('creatable' => false) }

    it 'resolves an existing name to its row id' do
      result = build('0' => { 'contributor' => 'Ada Lovelace', '_destroy' => 'false' })
      expect(result['0']['contributor']).to eq(ada.id.to_s)
    end

    it 'drops a miss without creating a record, and logs a warning' do
      expect(Rails.logger).to receive(:warn).with(/Mystery Person.*no matching record/)
      result = nil
      expect do
        result = build('0' => { 'contributor' => 'Mystery Person', '_destroy' => 'false' })
      end.not_to change(Enact::Contributor, :count)
      expect(result).to be_empty
    end
  end

  it 'is a no-op when there is no contributors_attributes' do
    entry = host_class.new(nil)
    entry.parsed_metadata.delete('contributors_attributes')
    expect { entry.build_metadata }.not_to raise_error
  end

  # The creatable branch above stubs the member; this confirms the real profile
  # lookup finds the contributor linked_record sub-property and reads its flag,
  # so the live import takes the find-or-create path the profile actually declares.
  it 'reads creatable from the real m3 profile (contributor_ref is creatable)' do
    member = described_class.linked_record_member(source: :contributors, compound: 'contributors')
    expect(member).to include('type' => 'linked_record', 'authority' => 'contributors', 'creatable' => true)
  end
end
