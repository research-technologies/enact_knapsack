# frozen_string_literal: true

# OVERRIDE Hyrax 5.2.0 (samvera/hyrax main @ f9f471f): make the FileSet show
# page render flexible metadata.
#
# hyrax/file_sets/_metadata.html.erb already has a flexible branch
# (`view_options_for(@presenter)` + `@presenter.try(field)`), and `flexible?`
# delegates through MissingMethodBehavior to the SolrDocument. But unlike
# Hyrax::WorkShowPresenter (which calls `define_dynamic_methods` in its
# initializer), Hyrax::FileSetPresenter defines no readers for the M3 profile
# fields, so `try(field)` returns nothing and the Metadata section renders
# empty. Mirror the work presenter so each indexed FileSet property gets a
# reader sourced from the Solr document.
#
# Tracked for upstreaming alongside the FileSet form compound fix
# (samvera/hyrax PR #7510) so this override can be dropped on a future bump.
module Hyrax
  module FileSetPresenterDecorator
    def initialize(solr_document, current_ability, request = nil)
      super
      define_flexible_methods if solr_document.try(:flexible?)
    end

    # Define a reader for every flexible property that carries indexing keys,
    # reading the first present indexed value off the Solr document. Mirrors
    # Hyrax::WorkShowPresenter#define_dynamic_methods, adapted for the FileSet
    # presenter (whose solr_document is not OrderedMembers-decorated).
    def define_flexible_methods
      # current_version is read once here (not inside the loop), matching
      # Hyrax::WorkShowPresenter#define_dynamic_methods. Deliberately not memoized
      # on the class: FlexibleSchema.current_version is per-tenant, so a
      # process-wide cache would leak one tenant's schema into another.
      Hyrax::FlexibleSchema.current_version["properties"].each do |method_name, property_details|
        index_keys = property_details["indexing"]
        next unless index_keys
        # Don't shadow real presenter methods (title, etc.).
        next if self.class.method_defined?(method_name)

        multi_value = property_details["multiple"] || (property_details["data_type"] == "array")

        self.class.send(:define_method, method_name) do |*_args|
          index_keys.each do |index_key|
            value = solr_document[index_key]
            return(multi_value ? Array.wrap(value) : value) if value.present?
          end
          multi_value ? [] : ""
        end
      end
    end

    # Credit/attribution is inferred from the `rights` compound's holder(s)
    # rather than entered as its own field (per client decision). Reads the
    # coerced `rights` rows off the Solr document (from the rights_json_ss blob)
    # and returns the distinct, non-blank holder values.
    # @return [Array<String>]
    def credit
      Array(try(:rights))
        .map { |row| row.respond_to?(:[]) ? (row["holder"] || row[:holder]) : nil }
        .map { |value| value.to_s.strip }
        .reject(&:blank?)
        .uniq
    end
  end
end

Hyrax::FileSetPresenter.prepend(Hyrax::FileSetPresenterDecorator)
