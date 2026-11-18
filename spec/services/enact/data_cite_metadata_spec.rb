# frozen_string_literal: true

require 'rails_helper'

# Supplies hyrax-pid's DataCite :creator/:publisher field_mapping values (see
# config/initializers/hyrax_pid.rb) from a work's `contributors` compound.
RSpec.describe Enact::DataCiteMetadata do
  let(:author) { Enact::Contributor.create!(display_name: 'Ada', agent_type: 'person', orcid: 'https://orcid.org/0000-0002-1825-0097') }
  let(:publisher) { Enact::Contributor.create!(display_name: 'Enact Press', agent_type: 'organization') }
  let(:work) { double('Work', contributors: entries) } # rubocop:disable RSpec/VerifiedDoubles

  describe '.creators_for' do
    context 'with a contributor tagged "author"' do
      let(:entries) { [{ contributor: author.id.to_s, role: ['author'] }] }

      it 'builds one DataCite creator per author-tagged entry' do
        expect(described_class.creators_for(work)).to eq(
          [
            {
              name: 'Ada',
              nameType: 'Personal',
              nameIdentifiers: [{ nameIdentifier: 'https://orcid.org/0000-0002-1825-0097', nameIdentifierScheme: 'ORCID', schemeUri: 'https://orcid.org' }]
            }
          ]
        )
      end
    end

    context 'with contributors tagged other roles only' do
      let(:entries) { [{ contributor: publisher.id.to_s, role: ['publisher'] }] }

      it 'returns an empty Array (no DataCite Creator) since none is tagged "author"' do
        expect(described_class.creators_for(work)).to eq([])
      end
    end

    context 'with a role stored as a bare string, not an Array' do
      let(:entries) { [{ 'contributor' => author.id.to_s, 'role' => 'author' }] }

      it 'still resolves it (tolerates single-value roles and string keys)' do
        expect(described_class.creators_for(work).first[:name]).to eq('Ada')
      end
    end

    context 'with an organization contributor and no identifiers' do
      let(:org) { Enact::Contributor.create!(display_name: 'A Lab', agent_type: 'organization') }
      let(:entries) { [{ contributor: org.id.to_s, role: ['author'] }] }

      it 'sets nameType Organizational and omits nameIdentifiers' do
        creator = described_class.creators_for(work).first
        expect(creator[:nameType]).to eq('Organizational')
        expect(creator).not_to have_key(:nameIdentifiers)
      end
    end

    it 'returns [] when the compound is empty' do
      expect(described_class.creators_for(double('Work', contributors: []))).to eq([]) # rubocop:disable RSpec/VerifiedDoubles
    end
  end

  describe '.publisher_for' do
    context 'with a contributor tagged "publisher"' do
      let(:entries) { [{ contributor: publisher.id.to_s, role: ['publisher'] }] }

      it "returns that contributor's display_name" do
        expect(described_class.publisher_for(work)).to eq('Enact Press')
      end
    end

    context 'with no contributor tagged "publisher"' do
      let(:entries) { [{ contributor: author.id.to_s, role: ['author'] }] }

      it 'returns nil (the metadata mapper fails loudly on a blank required field)' do
        expect(described_class.publisher_for(work)).to be_nil
      end
    end
  end
end
