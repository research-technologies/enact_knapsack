# frozen_string_literal: true

require 'rails_helper'
require 'hyrax/specs/shared_specs/hydra_works'

RSpec.describe Portfolio do
  subject(:work) { described_class.new }

  it_behaves_like 'a Hyrax::Work'

  describe 'schema-driven scalar attributes' do
    it { is_expected.to respond_to(:description) }
    it { is_expected.to respond_to(:context_statement) }
    it { is_expected.to respond_to(:date_created) }
    it { is_expected.to respond_to(:date_made_public) }
    it { is_expected.to respond_to(:date_range_of_outputs) }
    it { is_expected.to respond_to(:publisher) }
    it { is_expected.to respond_to(:portfolio_identifier) }
    it { is_expected.to respond_to(:keyword) }
    it { is_expected.to respond_to(:research_group) }
    it { is_expected.to respond_to(:file_access_level) }
    it { is_expected.to respond_to(:ref_unit_of_assessment) }
  end

  describe 'schema-driven compound attributes' do
    it { is_expected.to respond_to(:contributors) }
    it { is_expected.to respond_to(:funding_references) }
    it { is_expected.to respond_to(:rights) }
  end

  describe 'compound round-trip via persister', :clean_repo do
    let(:contributor) do
      { 'given_name' => 'Avery', 'family_name' => 'Brooks', 'role_label' => 'composer',
        'name_identifier' => '0000-0001-2345-6789' }
    end
    let(:rights) do
      { 'statement' => 'http://rightsstatements.org/vocab/InC-NC/1.0/',
        'license' => 'https://creativecommons.org/licenses/by/4.0/' }
    end

    it 'persists and reloads compound hash entries' do
      work.title = ['Test portfolio']
      work.contributors = [contributor]
      work.rights = [rights]

      saved = Hyrax.persister.save(resource: work)
      reloaded = Hyrax.query_service.find_by(id: saved.id)

      expect(reloaded.contributors.map { |c| c['given_name'] }).to contain_exactly('Avery')
      expect(reloaded.contributors.first['role_label']).to eq('composer')
      expect(reloaded.rights.first['statement']).to eq('http://rightsstatements.org/vocab/InC-NC/1.0/')
      expect(reloaded.rights.first['license']).to eq('https://creativecommons.org/licenses/by/4.0/')
    end
  end
end
