# frozen_string_literal: true

require 'rails_helper'

# Supplies hyrax-pid's DataCite :publication_year field_mapping value (see
# config/initializers/hyrax_pid.rb) from a work's `dates` compound in
# preference to `date_created`.
RSpec.describe Enact::DataCitePublicationYear do
  def work_double(dates: [], date_created: nil)
    double('Work', dates:, date_created:) # rubocop:disable RSpec/VerifiedDoubles
  end

  describe '.year_for' do
    it 'prefers a "Published"-typed dates entry over date_created' do
      work = work_double(
        dates: [{ type: 'Created', start_date: '2020-01-01' }, { type: 'Published', start_date: '2022-06-15' }],
        date_created: '2020-01-01'
      )

      expect(described_class.year_for(work)).to eq('2022')
    end

    it 'tolerates string-keyed dates entries' do
      work = work_double(dates: [{ 'type' => 'Published', 'start_date' => '2023-03-01' }])

      expect(described_class.year_for(work)).to eq('2023')
    end

    it 'falls back to date_created when no dates entry is typed "Published"' do
      work = work_double(dates: [{ type: 'Created', start_date: '2020-01-01' }], date_created: '2021-05-01')

      expect(described_class.year_for(work)).to eq('2021')
    end

    it 'falls back to the current year when both are blank' do
      work = work_double

      expect(described_class.year_for(work)).to eq(Time.current.year.to_s)
    end
  end
end
