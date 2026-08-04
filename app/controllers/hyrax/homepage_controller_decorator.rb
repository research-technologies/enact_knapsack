# frozen_string_literal: true

# OVERRIDE Hyku v7.1.0 Hyrax::HomepageController (the Hyku copy, not the Hyrax gem's) to supply
# the data the enact_home theme needs.
module Hyrax
  module HomepageControllerDecorator
    def index
      super
      return unless home_page_theme == 'enact_home'

      enact_home_counts
    end

    private

    # Not ids.size: a child work can be a member of more than one parent, so the number of
    # matching parents is not bounded by the number of recent items.
    PARENT_ROWS = 25

    def enact_home_facets
      @enact_home_facets ||= search_service.facet_field_response(
        'has_model_ssim',
        # Blacklight only sets mincount for configured facet fields, and Solr defaults it to 0, so
        # without this the facet lists every work type with zero hits.
        'facet.mincount' => '1',
        'f.has_model_ssim.facet.limit' => '-1'
      )
    end

    # Both keys are always present, zero included: the featured section interpolates :portfolios
    # into a pluralised key, which renders the translation hash itself if handed nil.
    def enact_home_counts
      counts = enact_home_model_counts

      @enact_home_counts = {
        items: counts.values.sum,
        portfolios: counts['Portfolio'].to_i
      }
    end

    def enact_home_model_counts
      works = ::Hyrax::ModelRegistry.work_rdf_representations

      enact_home_facets.aggregations['has_model_ssim']
                       .items
                       .select { |item| works.include?(item.value) }
                       .to_h { |item| [item.value, item.hits] }
    end
  end
end

Hyrax::HomepageController.prepend(Hyrax::HomepageControllerDecorator)
