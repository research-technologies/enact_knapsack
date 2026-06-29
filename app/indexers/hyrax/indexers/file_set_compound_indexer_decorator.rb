# frozen_string_literal: true

# OVERRIDE Hyrax 5.2.0 (samvera/hyrax main @ f9f471f): index FileSet compound
# metadata into Solr so it can render on the show page.
#
# Hyrax::Indexers::CompoundIndexer writes each compound's searchable sub-fields
# plus a `<compound>_json_ss` display blob. It is mixed into the work and
# collection indexers (PcdmObjectIndexer, PcdmCollectionIndexer) but NOT into
# Hyrax::Indexers::FileSetIndexer (which descends from ResourceIndexer). So a
# flexible FileSet's compounds (rights, provenance, contributors) never reach
# Solr, the SolrDocument can't coerce them, and the show page renders nothing.
# Mix the same indexer into the FileSet indexer.
#
# Tracked for upstreaming: Hyrax::Indexers::FileSetIndexer should include
# Hyrax::Indexers::CompoundIndexer, matching works and collections.
module Hyrax
  module Indexers
    module FileSetCompoundIndexerDecorator
      def self.prepended(base)
        base.include(Hyrax::Indexers::CompoundIndexer)
      end
    end
  end
end

Hyrax::Indexers::FileSetIndexer.prepend(Hyrax::Indexers::FileSetCompoundIndexerDecorator)
