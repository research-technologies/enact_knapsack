# frozen_string_literal: true

# OVERRIDE Hyrax 5.2.0 Hyrax::CompoundWorkResolver.path_for to accept a preloaded
# Solr document. Without it, a caller that already has the doc (Enact::PortfolioTree
# fetches a whole member set in one batch) triggers a Solr re-query per node just
# to classify it for routing - an N+1 that dominates the hierarchy render (#95).
module Hyrax
  module CompoundWorkResolverDecorator
    def path_for(id, doc: nil)
      return super(id) if doc.nil?

      path_for_doc(doc, id)
    end
  end
end

Hyrax::CompoundWorkResolver.singleton_class.prepend(Hyrax::CompoundWorkResolverDecorator)
