# frozen_string_literal: true

require 'rails_helper'

# The show-page contributors view: a work's `contributors` compound GROUPED by
# contributor, so a person with several roles (the storage shape is one entry
# per role) appears once with all of its roles. The display counterpart of
# Enact::ContributorGraph.
RSpec.describe Enact::WorkContributors do
  # A stand-in Solr doc carrying the raw contributors JSON blob.
  def work_doc(entries)
    SolrDocument.new(
      'id' => 'work-1',
      'contributors_json_ss' => entries.to_json
    )
  end

  let(:vron) { Enact::Contributor.create!(display_name: 'Vron', agent_type: 'person', orcid: 'https://orcid.org/0000-0002-1825-0097') }
  let(:ada)  { Enact::Contributor.create!(display_name: 'Ada', agent_type: 'person') }

  describe '#credits' do
    it 'groups entries by contributor, joining all role codes onto one credit' do
      doc = work_doc(
        [
          { 'contributor' => vron.id.to_s, 'role' => 'director' },
          { 'contributor' => vron.id.to_s, 'role' => 'choreographer' },
          { 'contributor' => ada.id.to_s, 'role' => 'software' }
        ]
      )

      credits = described_class.new(doc).credits
      expect(credits.length).to eq(2)

      vron_credit = credits.find { |c| c.id == vron.id.to_s }
      expect(vron_credit.label).to eq('Vron')
      expect(vron_credit.roles).to eq(%w[director choreographer])
      expect(vron_credit.orcid).to eq('https://orcid.org/0000-0002-1825-0097')
      expect(vron_credit.agent_type).to eq('person')
      expect(vron_credit.path).to be_present
    end

    it 'carries free-text role_other alongside controlled roles' do
      doc = work_doc(
        [{ 'contributor' => vron.id.to_s, 'role' => 'director', 'role_other' => 'Lighting design' }]
      )

      credit = described_class.new(doc).credits.first
      expect(credit.roles).to eq(['director'])
      expect(credit.role_other).to eq(['Lighting design'])
    end

    it 'renders an unresolved contributor id as a bare label with no path' do
      doc = work_doc([{ 'contributor' => '999999', 'role' => 'director' }])

      credit = described_class.new(doc).credits.first
      expect(credit.label).to eq('999999')
      expect(credit.path).to be_nil
      expect(credit.orcid).to be_nil
    end

    it 'returns [] when the compound is empty' do
      expect(described_class.new(work_doc([])).credits).to eq([])
    end

    it 'skips entries with no contributor id' do
      doc = work_doc([{ 'role' => 'director' }])
      expect(described_class.new(doc).credits).to eq([])
    end
  end
end
