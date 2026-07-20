# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IiifPrint::ExternalIiifDisplayImagePresenter do
  subject(:presenter) { described_class.new(solr_doc) }

  let(:solr_doc) { SolrDocument.new('storage_file_identifier_ss' => 'abc123/def456') }

  before do
    # A decoy value: if either method below still reads this, these specs fail.
    allow(IiifPrint.config).to receive(:external_iiif_url).and_return('https://should-not-be-used.example.com')
  end

  describe '#display_image_url' do
    it "builds the URL from the given base_url's own /iiif/2 path, not the static config" do
      url = presenter.display_image_url('https://tenant-a.enacthyku.com')

      expect(url).to start_with('https://tenant-a.enacthyku.com/iiif/2/')
      expect(url).not_to include('should-not-be-used')
      # Riiif's route helper re-escapes the already-CGI-escaped file id (the
      # literal `%` from `%2F` becomes `%25`), so this is double-encoded here.
      # Pre-existing behavior of Riiif::Engine.routes.url_helpers.image_url,
      # not something this decorator introduces -- see #iiif_endpoint below,
      # which builds via plain File.join and stays singly-encoded.
      expect(url).to include('abc123%252Fdef456')
    end

    context 'when no base_url is given' do
      it 'falls back to #base_url_for_iiif' do
        allow(presenter).to receive(:base_url_for_iiif).and_return('https://fallback-tenant.enacthyku.com')

        url = presenter.display_image_url

        expect(url).to start_with('https://fallback-tenant.enacthyku.com/iiif/2/')
      end
    end
  end

  describe '#iiif_endpoint' do
    it "builds the endpoint from the given base_url's own /iiif/2 path, not the static config" do
      endpoint = presenter.iiif_endpoint(nil, base_url: 'https://tenant-b.enacthyku.com')

      expect(endpoint.url).to eq 'https://tenant-b.enacthyku.com/iiif/2/abc123%2Fdef456'
    end

    context 'when no base_url is given' do
      it 'falls back to #base_url_for_iiif' do
        allow(presenter).to receive(:base_url_for_iiif).and_return('https://fallback-tenant.enacthyku.com')

        endpoint = presenter.iiif_endpoint

        expect(endpoint.url).to eq 'https://fallback-tenant.enacthyku.com/iiif/2/abc123%2Fdef456'
      end
    end
  end
end
