# frozen_string_literal: true

require 'rails_helper'

# The knapsack hides the "User Collections" dashboard sidebar link from
# non-admins so depositors do not mistake a user collection for the Portfolio
# work type. See research-technologies/enact_knapsack#94.
RSpec.describe 'hyrax/dashboard/sidebar/_repository_content', type: :view do
  let(:menu) { instance_double(Hyku::MenuPresenter) }

  before do
    # Isolate the partial under test from the metadata/menu sub-partials, which
    # reach for current_ability and controller-level sidebar config.
    stub_template 'hyrax/dashboard/sidebar/_metadata.html.erb' => ''
    stub_template 'hyrax/dashboard/sidebar/_menu_partials.html.erb' => ''
    # nav_link normally builds an <a>; render the block so we can assert on the
    # link labels that survive the admin gate.
    allow(menu).to receive(:nav_link) do |*_args, **_kwargs, &block|
      view.content_tag(:a, view.capture(&block), class: 'nav-link')
    end
    allow(view).to receive(:can?).and_call_original
    allow(view).to receive(:can?).with(:read, :admin_dashboard).and_return(admin)
    render 'hyrax/dashboard/sidebar/repository_content', menu:
  end

  context 'as an admin' do
    let(:admin) { true }

    it 'shows the User Collections link' do
      expect(rendered).to include(t('hyrax.admin.sidebar.collections'))
    end

    it 'shows the Works link' do
      expect(rendered).to include(t('hyrax.admin.sidebar.works'))
    end
  end

  context 'as a non-admin' do
    let(:admin) { false }

    it 'hides the User Collections link' do
      expect(rendered).not_to include(t('hyrax.admin.sidebar.collections'))
    end

    it 'still shows the Works link' do
      expect(rendered).to include(t('hyrax.admin.sidebar.works'))
    end
  end
end
