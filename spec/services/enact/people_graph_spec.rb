# frozen_string_literal: true

require 'rails_helper'

# The contributor collaboration network for the people map: contributors are
# nodes, linked where they share credit on a work (edge weight = shared works),
# coloured by institution. Mirrors Enact::ContributorGraph's design (the credit
# lives once on the work's `contributors` compound, read via an ability-scoped
# Solr query) so these specs mock the Solr chain rather than hit the repo.
RSpec.describe Enact::PeopleGraph do
  let(:ability) { instance_double(Ability) }

  # Build the network from the given work docs + contributor records, stubbing
  # the ability-scoped work query and the contributor batch-load.
  def run(docs, people)
    service = instance_double(Hyrax::SolrQueryService)
    allow(Hyrax::SolrQueryService).to receive(:new).and_return(service)
    allow(service).to receive(:with_field_pairs).and_return(service)
    allow(service).to receive(:accessible_by).and_return(service)
    allow(service).to receive(:solr_documents).and_return(docs)
    allow(Enact::Contributor).to receive(:where).and_return(people)
    described_class.new(ability:).call
  end

  def work_doc(id:, title:, entries:)
    SolrDocument.new('id' => id, 'title_tesim' => [title],
                     'has_model_ssim' => ['Portfolio'],
                     'contributors_json_ss' => entries.to_json)
  end

  def person(id, name, orcid: nil, affiliations: [], agent_type: 'person')
    instance_double(Enact::Contributor, id:, display_name: name, orcid:,
                                        affiliations:, agent_type:)
  end

  before do
    allow(Hyrax.config).to receive(:registered_curation_concern_types).and_return(['Portfolio'])
    # Deterministic label resolution so the spec does not depend on the authority.
    allow(Enact::ContributorRolesService).to receive(:label) { |code| code.to_s.tr('-', ' ').capitalize }
  end

  let(:ana) { person(1, 'Ana', orcid: '0000-0000-0000-0001', affiliations: ['University of Westminster']) }
  let(:ben) { person(2, 'Ben', affiliations: ['University of Leeds']) }
  let(:cai) { person(3, 'Cai', affiliations: []) } # unaffiliated

  describe '#call' do
    it 'makes one node per credited contributor, with works count and profile path' do
      docs = [work_doc(id: 'w1', title: 'Work One',
                       entries: [{ 'contributor' => '1' }, { 'contributor' => '2' }])]
      result = run(docs, [ana, ben])

      expect(result.nodes.map { |n| n[:label] }).to contain_exactly('Ana', 'Ben')
      ana_node = result.nodes.find { |n| n[:id] == '1' }
      expect(ana_node[:path]).to eq('/contributors/1')
      expect(ana_node[:works]).to eq(1)
      expect(ana_node[:orcid]).to eq('0000-0000-0000-0001')
    end

    it 'weights an edge by the number of works two people share, listing the titles' do
      docs = [
        work_doc(id: 'w1', title: 'Work One', entries: [{ 'contributor' => '1' }, { 'contributor' => '2' }]),
        work_doc(id: 'w2', title: 'Work Two',
                 entries: [{ 'contributor' => '1' }, { 'contributor' => '2' }, { 'contributor' => '3' }])
      ]
      result = run(docs, [ana, ben, cai])

      ab = result.links.find { |l| [l[:source], l[:target]].sort == %w[1 2] }
      expect(ab[:weight]).to eq(2)
      expect(ab[:works].map { |w| w[:title] }).to contain_exactly('Work One', 'Work Two')
      # 1-2 (twice), 1-3, 2-3 -> three distinct undirected edges
      expect(result.links.length).to eq(3)
    end

    it 'records, per shared work, the roles each endpoint played on it' do
      docs = [work_doc(id: 'w1', title: 'Work One',
                       entries: [{ 'contributor' => '1', 'role' => 'conceptualization', 'role_other' => 'Artist' },
                                 { 'contributor' => '2', 'role' => 'software' }])]
      result = run(docs, [ana, ben])

      ab = result.links.find { |l| [l[:source], l[:target]].sort == %w[1 2] }
      work = ab[:works].first
      expect(work[:title]).to eq('Work One')
      # source_roles/target_roles track the sorted key ends (source '1', target '2').
      expect(work[:source_roles]).to eq(['Artist', 'Conceptualization'])
      expect(work[:target_roles]).to eq(['Software'])
    end

    it 'skips free-text-only credits (no linked contributor becomes a node)' do
      docs = [work_doc(id: 'w1', title: 'Work One',
                       entries: [{ 'contributor' => '1' }, { 'role_other' => 'Uncredited guest' }])]
      result = run(docs, [ana])

      expect(result.nodes.map { |n| n[:label] }).to eq(['Ana'])
      expect(result.links).to be_empty
    end

    it 'aggregates a contributor\'s roles across works: controlled labels + free text' do
      docs = [
        work_doc(id: 'w1', title: 'Work One', entries: [{ 'contributor' => '1', 'role' => 'conceptualization' }]),
        work_doc(id: 'w2', title: 'Work Two', entries: [{ 'contributor' => '1', 'role_other' => 'Artist' }])
      ]
      result = run(docs, [ana])

      expect(result.nodes.first[:roles]).to eq(['Artist', 'Conceptualization'])
    end

    it 'colours by institution, bucketing the unaffiliated separately' do
      docs = [work_doc(id: 'w1', title: 'Work One',
                       entries: [{ 'contributor' => '1' }, { 'contributor' => '2' }, { 'contributor' => '3' }])]
      result = run(docs, [ana, ben, cai])

      labels = result.institutions.map { |i| i[:label] }
      expect(labels).to include('University of Westminster', 'University of Leeds', 'Independent / unaffiliated')
      expect(result.nodes.find { |n| n[:id] == '3' }[:inst]).to eq(Enact::PeopleGraph::Palette::UNAFFILIATED_KEY)
    end

    it 'flags truncation when the work cap is hit' do
      stub_const('Enact::PeopleGraph::MAX_WORKS', 1)
      docs = [work_doc(id: 'w1', title: 'Work One',
                       entries: [{ 'contributor' => '1' }, { 'contributor' => '2' }])]
      expect(run(docs, [ana, ben]).truncated).to be(true)
    end

    it 'does not flag truncation for a small corpus' do
      docs = [work_doc(id: 'w1', title: 'Work One',
                       entries: [{ 'contributor' => '1' }, { 'contributor' => '2' }])]
      expect(run(docs, [ana, ben]).truncated).to be(false)
    end
  end
end
