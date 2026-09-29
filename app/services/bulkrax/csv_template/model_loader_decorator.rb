# frozen_string_literal: true
# OVERRIDE Bulkrax 9.5.1 to remove CollectionResource row from the CSV template for Enact (not used)

module Bulkrax
  module CsvTemplate
    # Handles model loading based on configuration
    module ModelLoaderDecorator
      def all_available_models
        Hyrax.config.curation_concerns.map(&:name) +
          [Bulkrax.file_model_class&.name].compact
      end
    end
  end
end

Bulkrax::CsvTemplate::ModelLoader.prepend(Bulkrax::CsvTemplate::ModelLoaderDecorator)
