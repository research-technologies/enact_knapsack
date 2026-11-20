# frozen_string_literal: true

require 'rails_helper'

# RolesService freezes I18n.t results into DEFAULT_HYRAX_GROUPS_WITH_ATTRIBUTES when the class loads.
# If the knapsack's boot touches Ability before Hyku has put its locales on I18n.load_path, new tenants'
# default groups are seeded with "Translation missing: ..." as their names and descriptions.
RSpec.describe RolesService do
  it 'has real names and descriptions for the default groups' do
    values = described_class::DEFAULT_HYRAX_GROUPS_WITH_ATTRIBUTES.values.flat_map(&:values)

    expect(values).to all(satisfy { |value| value.present? && !value.to_s.start_with?('Translation missing') })
  end
end
