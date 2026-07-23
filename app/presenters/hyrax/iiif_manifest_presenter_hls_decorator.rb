# frozen_string_literal: true

# Threads the work's viewer down onto each file set presenter so DisplaysContent
# can decide whether to emit an HLS body.
module Hyrax
  module IiifManifestPresenterHlsDecorator
    def member_presenters
      viewer = chosen_media_viewer
      super.each { |presenter| presenter.media_viewer = viewer if presenter.respond_to?(:media_viewer=) }
    end

    def chosen_media_viewer
      model.try(:[], 'media_viewer_ssi').presence&.to_sym
    end

    module DisplayImagePresenterDecorator
      attr_accessor :media_viewer
    end
  end
end

Hyrax::IiifManifestPresenter.prepend(Hyrax::IiifManifestPresenterHlsDecorator)
Hyrax::IiifManifestPresenter::DisplayImagePresenter
  .prepend(Hyrax::IiifManifestPresenterHlsDecorator::DisplayImagePresenterDecorator)
