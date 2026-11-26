# frozen_string_literal: true

module Enact
  # Supplies hyrax-pid's DataCite :publication_year field_mapping value (see
  # config/initializers/hyrax_pid.rb) from a work's `dates` compound, in
  # preference to `date_created` -- `date_created` is when the *record* was
  # created, not necessarily when the work it describes was published, so a
  # `dates` entry explicitly typed "Published" is the better source when one
  # exists.
  module DataCitePublicationYear
    # The date_type controlled-vocabulary value (config/metadata_profiles/
    # m3_profile.yaml's inline `date_type` property) that identifies a
    # work's publication date among its (possibly several) `dates` entries.
    PUBLISHED_DATE_TYPE = "Published"

    module_function

    # @param work [#dates, #date_created]
    # @return [String] a 4-digit year: from a "Published"-typed `dates`
    #   entry if there is one, else from `date_created`, else the current
    #   year -- publication_year is one of DataCite's required fields, so
    #   this always returns something rather than leaving it blank
    def year_for(work)
      year_from_dates(work) || year_from_date_created(work) || Time.current.year.to_s
    end

    # @return [String, nil]
    def year_from_dates(work)
      entry = Array(work.try(:dates)).find { |e| fetch(e, :type).to_s == PUBLISHED_DATE_TYPE }
      return nil unless entry

      year_from(fetch(entry, :start_date))
    end

    # @return [String, nil]
    def year_from_date_created(work)
      year_from(Array(work.try(:date_created)).first)
    end

    def year_from(value)
      value.to_s[0, 4].presence
    end

    # Compound entry keys read tolerantly (symbol or string) -- see
    # Enact::DataCiteMetadata for the same pattern on `contributors` entries.
    def fetch(entry, key)
      entry[key] || entry[key.to_s]
    end
  end
end
