# frozen_string_literal: true

# OVERRIDE Hyku v7.1.0 Hyrax::HomepageController (the Hyku copy, not the Hyrax gem's) to supply
# the data the enact_home theme needs.
module Hyrax
  module HomepageControllerDecorator
    def index
      super
      return unless home_page_theme == 'enact_home'

      enact_home_featured
      enact_home_counts
      enact_home_browse
      enact_home_item_counts
      enact_home_recent_parents
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

    # FeaturedWorkList is not access-filtered: Hyrax's PresenterFactory loads the documents with a
    # nil ability, so a work featured while public and later made private keeps rendering, and this
    # theme's card would publish its context statement and contributors.
    def enact_home_featured
      featured = @featured_work_list.featured_works
      readable = enact_home_readable_ids(featured.map { |work| work.presenter.id })

      @enact_home_featured = featured.select { |work| readable.include?(work.presenter.id) }
    end

    # Sorted here rather than by Solr: facet.sort defaults to index, not count, whenever
    # facet.limit is negative.
    def enact_home_browse
      @enact_home_work_types = enact_home_model_counts.except('Portfolio')
                                                      .sort_by { |_model, count| -count }
                                                      .to_h
    end

    def enact_home_item_counts
      @enact_home_item_counts = @enact_home_featured.to_a.to_h do |work|
        [work.presenter.id, enact_home_child_work_count(work.presenter.solr_document)]
      end
    end

    # A count, not a fetch: member_ids_ssim carries file sets as well as child works, and a portfolio
    # can hold thousands of members, so asking Solr for numFound keeps this one request per card
    # however large the portfolio. `{!terms}` rather than an id disjunction because a TermsQuery is
    # not subject to maxBooleanClauses, and the chain still supplies the access filter and the
    # only_works? model filter that excludes the file sets.
    def enact_home_child_work_count(document)
      member_ids = Array(document['member_ids_ssim'])
      return 0 if member_ids.empty?

      (response, _documents) = search_service.search_results do |builder|
        builder.rows(0)
        builder.merge(q: "{!terms f=id}#{member_ids.join(',')}", fl: 'id')
      end

      response.total
    end

    # A child carries no parent field, so this is a reverse lookup on member_ids_ssim. The
    # restriction goes in q, not fq: SearchBuilder#merge is a shallow Hash merge, so an fq would
    # replace the processor chain's access filter. Leading local params still beat defType.
    def enact_home_recent_parents
      ids = Array(@recent_documents).map(&:id)
      return @enact_home_recent_parents = {} if ids.empty?

      (_, documents) = search_service.search_results do |builder|
        builder.rows(PARENT_ROWS)
        builder.merge(q: "{!terms f=member_ids_ssim}#{ids.join(',')}",
                      fl: 'id,title_tesim,has_model_ssim,member_ids_ssim')
      end

      @enact_home_recent_parents = ids.index_with { |id| enact_home_parent_of(documents, id) }.compact
    end

    def enact_home_parent_of(documents, child_id)
      parents = documents.select { |doc| Array(doc['member_ids_ssim']).include?(child_id) }

      parents.find { |doc| Array(doc['has_model_ssim']).include?('Portfolio') } || parents.first
    end

    # fetch, not search_results with a merged fq: SearchBuilder#merge is a shallow Hash merge, so
    # an fq would replace the processor chain's own, which is where both the access filter and
    # HomepageSearchBuilder's only_works? model filter live.
    def enact_home_readable_ids(ids)
      return [] if ids.empty?

      (_, documents) = search_service.fetch(ids, rows: ids.size, fl: 'id')

      documents.map(&:id)
    end
  end
end

Hyrax::HomepageController.prepend(Hyrax::HomepageControllerDecorator)
