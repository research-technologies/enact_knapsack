# frozen_string_literal: true

# OVERRIDE Hyku v7.1.0 to allow the work's media_viewer_ssi to dictate which viewer is used

module Hyku
  module WorkShowPresenterDecorator
    def iiif_viewer
      viewer = chosen_viewer
      %i[universal_viewer clover ramp].include?(viewer) ? viewer : super
    end

    def iiif_viewer?
      return false if chosen_viewer == :pdf_js
      return super unless %i[universal_viewer clover ramp].include?(chosen_viewer)

      representative_id.present? && representative_presenter.present?
    end

    def show_pdf_viewer?
      return true if chosen_viewer == :pdf_js && file_set_presenters.any?(&:pdf?)

      super
    end

    private

    def chosen_viewer
      solr_document['media_viewer_ssi'].presence&.to_sym
    end
  end
end

Hyku::WorkShowPresenter.prepend(Hyku::WorkShowPresenterDecorator)
