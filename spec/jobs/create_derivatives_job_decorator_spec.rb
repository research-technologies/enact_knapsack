# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CreateDerivativesJobDecorator do
  let(:job) { CreateDerivativesJob.new }

  describe '#perform' do
    context 'when the file set is a video' do
      let(:file_set) { double('file_set', id: double(to_s: 'fs-vid'), video?: true, audio?: false) }

      before { allow(file_set).to receive(:respond_to?).with(:video?).and_return(true) }

      it 'enqueues CreateLargeDerivativesJob and returns true' do
        allow(CreateLargeDerivativesJob).to receive(:perform_later)
        result = job.perform(file_set, 'file-id', nil)
        expect(CreateLargeDerivativesJob).to have_received(:perform_later)
        expect(result).to be true
      end
    end

    context 'when the file set is audio' do
      let(:file_set) { double('file_set', id: double(to_s: 'fs-aud'), video?: false, audio?: true) }

      before { allow(file_set).to receive(:respond_to?).with(:video?).and_return(true) }

      it 'enqueues CreateLargeDerivativesJob' do
        allow(CreateLargeDerivativesJob).to receive(:perform_later)
        job.perform(file_set, 'file-id', nil)
        expect(CreateLargeDerivativesJob).to have_received(:perform_later)
      end
    end
  end

  describe '#large_media_file_set? (private)' do
    context 'when file_set responds to video? and is a video' do
      let(:file_set) { double('file_set', video?: true, audio?: false) }

      before { allow(file_set).to receive(:respond_to?).with(:video?).and_return(true) }

      it { expect(job.send(:large_media_file_set?, file_set)).to be true }
    end

    context 'when file_set responds to audio? and is audio' do
      let(:file_set) { double('file_set', video?: false, audio?: true) }

      before { allow(file_set).to receive(:respond_to?).with(:video?).and_return(true) }

      it { expect(job.send(:large_media_file_set?, file_set)).to be true }
    end

    context 'when file_set responds to video? and is neither' do
      let(:file_set) { double('file_set', video?: false, audio?: false) }

      before { allow(file_set).to receive(:respond_to?).with(:video?).and_return(true) }

      it { expect(job.send(:large_media_file_set?, file_set)).to be false }
    end

    context 'when file_set does not respond to video? (Valkyrie resource)' do
      let(:file_set) { double('valkyrie_file_set', id: double(to_s: 'fs-v')) }
      let(:solr_doc) { instance_double(SolrDocument) }

      before do
        allow(file_set).to receive(:respond_to?).with(:video?).and_return(false)
        allow(SolrDocument).to receive(:find).with('fs-v').and_return(solr_doc)
      end

      context 'with a video MIME type' do
        before { allow(solr_doc).to receive(:[]).with('mime_type_ssi').and_return('video/mp4') }

        it { expect(job.send(:large_media_file_set?, file_set)).to be true }
      end

      context 'with an audio MIME type' do
        before { allow(solr_doc).to receive(:[]).with('mime_type_ssi').and_return('audio/mpeg') }

        it { expect(job.send(:large_media_file_set?, file_set)).to be true }
      end

      context 'with an image MIME type' do
        before { allow(solr_doc).to receive(:[]).with('mime_type_ssi').and_return('image/tiff') }

        it { expect(job.send(:large_media_file_set?, file_set)).to be false }
      end

      context 'with a nil MIME type' do
        before { allow(solr_doc).to receive(:[]).with('mime_type_ssi').and_return(nil) }

        it { expect(job.send(:large_media_file_set?, file_set)).to be false }
      end
    end
  end
end
