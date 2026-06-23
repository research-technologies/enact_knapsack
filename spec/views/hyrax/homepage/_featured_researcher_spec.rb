# frozen_string_literal: true

require 'rails_helper'

# The knapsack brings forward _featured_researcher and adds a "View all
# researchers" button (styled like the view-all-collections button) linking to
# the contributors browse index.
RSpec.describe 'hyrax/homepage/_featured_researcher', type: :view do
  let(:content_block) { instance_double('ContentBlock', value: block_value) }

  before do
    assign(:featured_researcher, content_block)
    # displayable_content_block is a Hyrax helper not mixed into the bare view
    # object; relax partial-double verification to stub it.
    without_partial_double_verification do
      allow(view).to receive(:displayable_content_block).and_return('<p>Featured blurb</p>'.html_safe)
    end
    render
  end

  context 'with a curated featured-researcher block' do
    let(:block_value) { '<p>Featured blurb</p>' }

    it 'renders the curated content' do
      expect(rendered).to include('Featured blurb')
    end

    it 'renders a View all research profiles button to the contributors index' do
      expect(rendered).to have_css('a.btn.btn-secondary[href="/contributors"]', text: 'View all research profiles')
    end
  end

  context 'with no featured-researcher block set' do
    let(:block_value) { nil }

    it 'still renders the View all researchers button' do
      expect(rendered).to have_css('a.btn.btn-secondary[href="/contributors"]')
    end
  end
end
