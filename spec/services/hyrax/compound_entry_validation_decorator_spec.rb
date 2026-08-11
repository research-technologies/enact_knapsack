# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Hyrax::CompoundEntryValidationDecorator do
  # Mirrors the normalized definition CompoundSchema builds for `dates`.
  let(:definition) do
    { required: false,
      subproperties: {
        'start_date' => { type: 'datepicker', required: true },
        'end_date' => { type: 'datepicker', required: false },
        'type' => { type: 'controlled', required: false }
      } }
  end

  def violations_for(entries)
    Hyrax::CompoundEntryValidation.new(definition, entries).violations
  end

  it 'accepts an end date after the start date' do
    expect(violations_for([{ 'start_date' => '2026-01-01', 'end_date' => '2026-06-30' }])).to be_empty
  end

  it 'accepts a row with no end date' do
    expect(violations_for([{ 'start_date' => '2026-01-01' }])).to be_empty
  end

  it 'accepts an end date equal to the start date (a single-day range)' do
    expect(violations_for([{ 'start_date' => '2026-01-01', 'end_date' => '2026-01-01' }])).to be_empty
  end

  it 'rejects an end date before the start date' do
    violations = violations_for([{ 'start_date' => '2026-06-30', 'end_date' => '2026-01-01' }])

    expect(violations).to contain_exactly(hash_including(type: :end_before_start))
  end

  # One message however many rows are wrong, matching how Hyrax dedupes its own
  # missing-required violations: the depositor sees the rule once, not per row.
  it 'reports a single violation even when several rows are out of order' do
    violations = violations_for([{ 'start_date' => '2026-06-30', 'end_date' => '2026-01-01' },
                                 { 'start_date' => '2025-06-30', 'end_date' => '2025-01-01' }])

    expect(violations.count { |v| v[:type] == :end_before_start }).to eq(1)
  end

  it 'still reports a missing required sub-property' do
    violations = violations_for([{ 'end_date' => '2026-01-01' }])

    expect(violations).to contain_exactly(hash_including(type: :missing_required_subproperties))
  end

  it 'ignores unparseable dates rather than raising' do
    expect(violations_for([{ 'start_date' => 'circa 1920', 'end_date' => 'later' }])).to be_empty
  end

  it 'leaves compounds without both date fields alone' do
    other = { required: false,
              subproperties: { 'funder_name' => { type: 'string', required: true } } }

    expect(Hyrax::CompoundEntryValidation.new(other, [{ 'funder_name' => 'AHRC' }]).violations).to be_empty
  end

  describe 'the error message' do
    it 'has a translation' do
      expect(I18n.t('hyrax.compound_fields.errors.end_before_start', compound: 'Dates', fields: ''))
        .not_to match(/translation missing/)
    end
  end
end
