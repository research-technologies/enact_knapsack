# frozen_string_literal: true

# OVERRIDE Hyrax 5.x (samvera/hyrax main @ ab3f45b): add an enact-specific
# `credit` reader to the FileSet presenter.
#
# Hyrax::FileSetPresenter now defines readers for flexible-profile fields
# (#define_dynamic_methods, called from its initializer) and renders/indexes
# compounds, so the former define_flexible_methods shim this decorator carried
# is gone. What remains is purely enact: credit/attribution is inferred from the
# `rights` compound's holder(s) rather than entered as its own field (per client
# decision). `rights` returns the coerced compound rows via the SolrDocument
# (the same path the rights card renders from); take the distinct, non-blank
# holder values.
module Hyrax
  module FileSetPresenterDecorator
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
