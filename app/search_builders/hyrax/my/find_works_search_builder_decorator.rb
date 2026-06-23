# frozen_string_literal: true

# OVERRIDE Hyrax v5.2.0 Hyrax::My::FindWorksSearchBuilder#filter_on_title
#
# The child-work picker (Relationships tab "find a child work", backed by
# /qa/search/find_works) found nothing for partial input. Two upstream behaviors
# combined to cause it:
#   1. `filter_on_title` adds `{!field f=title_tesim}<q>`, a whole-FIELD exact
#      match (only a work's COMPLETE title matches), and
#   2. the typed term is ALSO passed as `params[:q]`, which drives the main
#      `dismax` query over analyzed fields — so a partial word like "Repel"
#      matches no documents, and the title `fq` only filters an already-empty
#      set.
#
# Fixing the `fq` alone is not enough because the dismax `q` zeroes the results
# first. So we mirror Hyrax::CompoundWorkPickerBuilder (the relationship-item
# picker, which already finds works/collections by partial word correctly):
# replace `solr_parameters[:q]` with a `lucene` query that ORs a multi-field
# term match with a prefix-wildcard title match, and drop the exact-match title
# `fq`. The permission, type, and self/child/parent exclusion filters in the
# rest of the processor chain are untouched.
module Hyrax
  module My
    module FindWorksSearchBuilderDecorator
      QUERY_FIELDS = %w[title_tesim description_tesim creator_tesim keyword_tesim].freeze

      # Replace the exact-match title filter with a partial-word query on `q`.
      def filter_on_title(solr_parameters)
        term = @q.to_s.strip
        return if term.blank?

        solr_parameters[:q] = "#{multi_field_clause(term)} OR #{prefix_title_clause(term)}"
        solr_parameters[:defType] = 'lucene'
      end

      private

      def multi_field_clause(term)
        escaped = escape(term)
        QUERY_FIELDS.map { |field| "#{field}:(#{escaped})" }.join(' OR ')
      end

      # Prefix-wildcard on each whitespace-separated title token, e.g.
      # "repel ani" -> title_tesim:(repel* AND ani*).
      def prefix_title_clause(term)
        tokens = term.split(/\s+/).reject(&:empty?).map { |t| "#{escape_token(t)}*" }
        return '' if tokens.empty?

        "title_tesim:(#{tokens.join(' AND ')})"
      end

      # Escape Solr/Lucene specials in a phrase (wildcards included — the
      # multi-field clause is not a prefix search).
      def escape(value)
        value.to_s.gsub(%r{([+\-&|!(){}\[\]^"~*?:\\/])}, '\\\\\1')
      end

      # Escape specials in a single token but keep it usable as a prefix (the
      # trailing `*` is added by the caller, not escaped here).
      def escape_token(value)
        value.to_s.gsub(%r{([+\-&|!(){}\[\]^"~?:\\/])}, '\\\\\1')
      end
    end
  end
end

Hyrax::My::FindWorksSearchBuilder.prepend(Hyrax::My::FindWorksSearchBuilderDecorator)
