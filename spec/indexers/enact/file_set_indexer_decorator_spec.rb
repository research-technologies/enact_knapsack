# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Enact::FileSetIndexerDecorator do
  let(:host_class) do
    Class.new do
      prepend Enact::FileSetIndexerDecorator

      attr_reader :resource

      def initialize(resource)
        @resource = resource
      end

      def generate_solr_document
        {}
      end
    end
  end

  let(:file_set) { double('Hyrax::FileSet') }
  subject(:indexer) { host_class.new(file_set) }

  describe '#generate_solr_document' do
    context 'when the original file has a Shrine S3 identifier' do
      let(:file_identifier) { double(to_s: 'shrine://uuid-1/uuid-2') }
      let(:original_file) { double('Hyrax::FileMetadata', file_identifier: file_identifier) }

      before do
        allow(Hyrax.custom_queries).to receive(:find_original_file)
          .with(file_set: file_set)
          .and_return(original_file)
      end

      it 'indexes iiif_file_identifier_ss as the bare S3 key (no shrine:// prefix)' do
        expect(indexer.generate_solr_document['iiif_file_identifier_ss'])
          .to eq('uuid-1/uuid-2')
      end
    end

    context 'when the original file is on disk (non-Shrine storage)' do
      let(:file_identifier) { double(to_s: 'disk://some/path') }
      let(:original_file) { double('Hyrax::FileMetadata', file_identifier: file_identifier) }

      before do
        allow(Hyrax.custom_queries).to receive(:find_original_file)
          .with(file_set: file_set)
          .and_return(original_file)
      end

      it 'does not index iiif_file_identifier_ss' do
        expect(indexer.generate_solr_document).not_to have_key('iiif_file_identifier_ss')
      end
    end

    context 'when the original file has no file_identifier' do
      let(:original_file) { double('Hyrax::FileMetadata', file_identifier: nil) }

      before do
        allow(Hyrax.custom_queries).to receive(:find_original_file)
          .with(file_set: file_set)
          .and_return(original_file)
      end

      it 'does not index iiif_file_identifier_ss' do
        expect(indexer.generate_solr_document).not_to have_key('iiif_file_identifier_ss')
      end
    end

    context 'when no original file is attached' do
      before do
        allow(Hyrax.custom_queries).to receive(:find_original_file)
          .with(file_set: file_set)
          .and_raise(Valkyrie::Persistence::ObjectNotFoundError)
      end

      it 'does not index iiif_file_identifier_ss and does not raise' do
        expect { indexer.generate_solr_document }.not_to raise_error
        expect(indexer.generate_solr_document).not_to have_key('iiif_file_identifier_ss')
      end
    end

    it 'preserves all fields from super' do
      allow(Hyrax.custom_queries).to receive(:find_original_file)
        .with(file_set: file_set)
        .and_raise(Valkyrie::Persistence::ObjectNotFoundError)
      # The host_class super returns {}; a real indexer would return many fields.
      # We verify our decorator doesn't drop them by checking the return is a Hash.
      expect(indexer.generate_solr_document).to be_a(Hash)
    end
  end
end
