# frozen_string_literal: true

module Enact
  # Adds the short SPDX code to Hyrax's license service, for the masthead badge where the
  # full term ("Creative Commons Attribution 4.0 International") does not fit.
  class LicensesService < Hyrax::LicenseService
    # Called on the class so the memo below is shared, rather than rebuilt per render.
    def self.short_label(id)
      (@instance ||= new).short_label(id)
    end

    # licenses.yml carries a non-standard `licenseId:` alongside `term:`, and QA passes
    # unrecognised keys straight through.
    def short_label(id)
      found = term(id)

      found['licenseId'].presence || found['term'].presence || id.to_s
    end

    private

    # Memoised: Qa's find re-parses the whole 109KB file per call, ~23ms. Not authority.all,
    # which normalises entries and drops the custom licenseId key.
    def term(id)
      key = id.to_s
      @terms ||= {}

      @terms.fetch(key) { @terms[key] = authority.find(key) }
    end
  end
end
