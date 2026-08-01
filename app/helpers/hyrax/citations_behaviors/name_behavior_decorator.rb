# frozen_string_literal: true

# OVERRIDE Hyrax v5.2.0 NameBehavior#all_authors to cite the contributors compound.
#
# Upstream reads `work.creator`, which every Enact work type defines as a nil stub (see
# Portfolio) because authorship lives in the `contributors` compound, so every citation
# came out authorless.
module Hyrax
  module CitationsBehaviors
    module NameBehaviorDecorator
      def all_authors(work, &block)
        authors = super
        return authors if authors.present?

        names = work.try(:enact_contributor_names) ||
                Enact::WorkContributors.new(work.try(:solr_document) || work)
                                       .credits.map(&:label).compact_blank

        block_given? ? names.map(&block) : names
      end
    end
  end
end

Hyrax::CitationsBehaviors::NameBehavior.prepend(Hyrax::CitationsBehaviors::NameBehaviorDecorator)
