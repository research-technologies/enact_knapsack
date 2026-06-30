# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Hyku::WorkShowPresenterDecorator do
  subject(:presenter) { Hyku::WorkShowPresenter.new(solr_document, ability, nil) }

  let(:solr_document) { SolrDocument.new({ 'media_viewer_ssi' => selected_viewer }.compact) }
  let(:selected_viewer) { nil }
  let(:ability) { instance_double(Ability) }

  describe '#iiif_viewer' do
    context 'when clover is chosen' do
      let(:selected_viewer) { 'clover' }

      it { expect(presenter.iiif_viewer).to eq(:clover) }
    end

    context 'when universal_viewer is chosen' do
      let(:selected_viewer) { 'universal_viewer' }

      it { expect(presenter.iiif_viewer).to eq(:universal_viewer) }
    end

    context 'when unset' do
      it 'falls back to super, the stock :universal_viewer default' do
        expect(presenter.iiif_viewer).to eq(:universal_viewer)
      end
    end

    context 'when pdf_js is chosen' do
      let(:selected_viewer) { 'pdf_js' }

      it 'falls back to super, since pdf_js is not an IIIF viewer' do
        expect(presenter.iiif_viewer).to eq(:universal_viewer)
      end
    end
  end

  describe '#iiif_viewer?' do
    context 'when pdf_js is chosen' do
      let(:selected_viewer) { 'pdf_js' }

      it 'is false even when super would show a viewer' do
        allow(presenter).to receive_messages(representative_id: '1',
                                             representative_presenter: double('file_set_presenter'),
                                             image_viewable?: true, members_include_viewable_image?: true)
        allow(Hyrax.config).to receive(:iiif_image_server?).and_return(true)

        expect(presenter.iiif_viewer?).to be(false)
      end
    end

    context 'when universal_viewer is chosen and the work has a representative' do
      let(:selected_viewer) { 'universal_viewer' }

      it 'is true, forcing the IIIF branch even for a non-image representative such as a PDF' do
        allow(presenter).to receive_messages(representative_id: '1',
                                             representative_presenter: double('file_set_presenter'))
        expect(presenter.iiif_viewer?).to be(true)
      end
    end

    context 'when an IIIF viewer is chosen but the work has no representative' do
      let(:selected_viewer) { 'clover' }

      it 'is false' do
        expect(presenter.iiif_viewer?).to be_falsey
      end
    end
  end

  describe '#show_pdf_viewer?' do
    let(:pdf) { double('file_set_presenter', pdf?: true) }
    let(:image) { double('file_set_presenter', pdf?: false) }

    context 'when pdf_js is chosen and a PDF file set is present' do
      let(:selected_viewer) { 'pdf_js' }

      it 'is true' do
        allow(presenter).to receive(:file_set_presenters).and_return([image, pdf])
        expect(presenter.show_pdf_viewer?).to be(true)
      end
    end

    context 'when pdf_js is chosen but no PDF file set is present' do
      let(:selected_viewer) { 'pdf_js' }

      it 'defers to super' do
        allow(presenter).to receive(:file_set_presenters).and_return([image])
        expect(presenter.show_pdf_viewer?).to be_falsey
      end
    end

    context 'when pdf_js is not chosen' do
      let(:selected_viewer) { 'clover' }

      it 'defers to super' do
        allow(presenter).to receive(:file_set_presenters).and_return([pdf])
        expect(presenter.show_pdf_viewer?).to be_falsey
      end
    end
  end
end
