# frozen_string_literal: true

# OVERRIDE Hyrax 5.2.0 Hyrax::CompoundWorkResolver.path_for to accept a preloaded
# Solr document.
#
# path_for(id) classifies a record (collection vs work) to route it, and does so
# by re-querying Solr for that one id. A caller that already holds the indexed
# doc - notably Enact::PortfolioTree, which fetches an entire member set in one
# batch - would otherwise trigger one extra Solr round-trip per node, an N+1 that
# dominates the hierarchy card render for large portfolios (issue #95). When a
# doc is supplied, skip the re-query and classify from it directly.
module Hyrax
  module CompoundWorkResolverDecorator
    def path_for(id, doc: nil)
      return super(id) if doc.nil?

      path_for_doc(doc, id)
    end
  end
end

Hyrax::CompoundWorkResolver.singleton_class.prepend(Hyrax::CompoundWorkResolverDecorator)
