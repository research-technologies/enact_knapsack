# frozen_string_literal: true

module Hyrax
  # OVERRIDE Hyrax v5.2.0 Hyrax::CompoundEntryValidation to reject a compound row
  # whose end date precedes its start date. The `dates` compound requires
  # `start_date` and leaves `end_date` optional, but nothing enforced the order.
  #
  # CONTRIBUTE BACK: the generic form of this is a profile-declared rule, e.g.
  #
  #   dates:
  #     validations:
  #       - { type: ordered, before: start_date, after: end_date }
  #
  # carried through CompoundSchema#normalize_definition into the definition hash, so
  # any compound with two comparable fields (award dates, embargo ranges) gets the
  # same check. This override hardcodes the two field names instead, which is why it
  # stays in Enact until that lands upstream.
  #
  # The `hyrax.compound_fields.errors.end_before_start` message in
  # config/locales/enact_compound_fields.en.yml goes with it; the sub-property labels
  # in that file do not.
  module CompoundEntryValidationDecorator
    START_KEY = 'start_date'
    END_KEY = 'end_date'

    def violations
      # Defer to Hyrax while a row is still missing a required field: reporting
      # both "start date is required" and "end date is before start" for the same
      # row is noise, and there is nothing to compare anyway.
      existing = super
      return existing if existing.any?

      out_of_order_rows.any? ? [{ type: :end_before_start, missing: [END_KEY] }] : []
    end

    private

    def out_of_order_rows
      return [] unless compares_dates?

      populated_rows.select do |row|
        finish = parse_date(row[END_KEY] || row[END_KEY.to_sym])
        start = parse_date(row[START_KEY] || row[START_KEY.to_sym])

        finish && start && finish < start
      end
    end

    def compares_dates?
      subs = definition.fetch(:subproperties, {})
      subs.key?(START_KEY) && subs.key?(END_KEY)
    end

    # nil for a partial or free-text date ("circa 1920"), which the profile permits;
    # an unparseable value simply isn't compared.
    def parse_date(value)
      return if value.blank?

      Date.parse(value.to_s)
    rescue ArgumentError, TypeError
      nil
    end
  end
end

Hyrax::CompoundEntryValidation.prepend(Hyrax::CompoundEntryValidationDecorator)
