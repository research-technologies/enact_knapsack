# frozen_string_literal: true

# OVERRIDE Hyrax::Indexers::FileSetIndexer — index the Shrine S3 storage key at
# index time so IIIF manifests can resolve the key without an extra Valkyrie query.
#
# The serverless-iiif Lambda reads files from the Valkyrie repository S3 bucket.
# Shrine stores each file under "uuid1/uuid2"; we write that key to a dedicated
# Solr field so the display image presenter can read it directly from the
# SolrDocument rather than calling Valkyrie on every manifest request.
#
# Remove when: IiifPrint has a first-class hook for the IIIF identifier.
module Enact
  module FileSetIndexerDecorator
    def generate_solr_document
      super.tap do |solr_doc|
        original = Hyrax.custom_queries.find_original_file(file_set: resource)
        identifier = original&.file_identifier&.to_s
        solr_doc['iiif_file_identifier_ss'] = identifier.sub('shrine://', '') if identifier&.start_with?('shrine://')
      rescue Valkyrie::Persistence::ObjectNotFoundError
        # No original file yet — field stays absent, manifest will skip this canvas
      end
    end
  end
end

'Hyrax::Indexers::FileSetIndexer'.safe_constantize&.prepend(Enact::FileSetIndexerDecorator)
