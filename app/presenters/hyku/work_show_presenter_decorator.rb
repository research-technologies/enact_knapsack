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

    def enact_contributor_names
      @enact_contributor_names ||=
        Enact::WorkContributors.new(solr_document).credits.map(&:label).compact_blank
    end

    # [file set ids, child work ids], both in deposit order. Pagination lives in
    # EnactThemeHelper: it needs request params, while this needs the private
    # authorized_item_ids.
    #
    # Not file_set_presenters/work_presenters: they filter on generic_type, which is nil on
    # every Valkyrie document here, so both come back empty. They also apply no access
    # filter despite the factory's class comment.
    #
    # An id with no indexed document drops out, which is what keeps a stale member_ids
    # entry from raising out of member_presenters.
    def enact_member_ids
      @enact_member_ids ||= begin
        models = enact_member_models
        file_set_models = ::Hyrax::ModelRegistry.file_set_rdf_representations

        authorized_item_ids.select { |id| models.key?(id.to_s) }
                           .partition { |id| file_set_models.include?(models[id.to_s]) }
      end
    end

    private

    # OVERRIDE: Hyrax picks the renderer from the profile's `render_as` alone,
    # ignoring the field. Routing on the field instead leaves the profile untouched —
    # the profile is only a seed, so editing it would need the stored
    # hyrax_flexible_schemas row reloaded before taking effect anywhere — and keeps
    # the other faceted properties (publisher, keyword, ...) on their facet links.
    #
    # CONTRIBUTE BACK: no Hyrax renderer labels a value from its property's own
    # authority — `faceted` links the raw value and license/rights are hardcoded to
    # their services. A generic `render_as: controlled` upstream would replace the
    # routing here; Enact would still need ItemSubtypeLabels, since item_subtype
    # draws from four authorities and `controlled_values.sources` is read
    # first-entry-only.
    def renderer_for(field, options)
      return Hyrax::Renderers::ItemSubtypeAttributeRenderer if field.to_s == 'item_subtype'

      super
    end

    def enact_member_models
      ids = authorized_item_ids
      return {} if ids.empty?

      Hyrax::SolrService.post(q: "{!terms f=id}#{ids.join(',')}", rows: ids.size,
                              fl: 'id,has_model_ssim')
                        .dig('response', 'docs')
                        .to_a
                        .to_h { |doc| [doc['id'], Array(doc['has_model_ssim']).first.to_s] }
    end

    def chosen_viewer
      solr_document['media_viewer_ssi'].presence&.to_sym
    end
  end
end

Hyku::WorkShowPresenter.prepend(Hyku::WorkShowPresenterDecorator)
