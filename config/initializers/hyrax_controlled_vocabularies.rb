# frozen_string_literal: true

# OVERRIDE Hyku v7.1.0 to add Hyrax::MediaViewerService to its services

module Hyrax
  module ControlledVocabulariesDecorator
    def services
      super.merge('media_viewer' => 'Hyrax::MediaViewerService')
    end
  end
end

Hyrax::ControlledVocabularies.singleton_class.prepend(Hyrax::ControlledVocabulariesDecorator)
