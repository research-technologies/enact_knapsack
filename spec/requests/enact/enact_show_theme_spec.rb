# frozen_string_literal: true

require 'rails_helper'

# End-to-end render of the enact_show theme, covering the files/child-works split.
# Stubbing show_page_theme is how Hyku's own show_page_theme_spec selects a theme
# without driving the admin form.
RSpec.describe 'enact_show theme', type: :request, singletenant: true do
  include Devise::Test::IntegrationHelpers

  let(:admin) { FactoryBot.create(:admin) }
  let(:file_set) { valkyrie_create(:hyrax_file_set, title: ['Bound portfolio.pdf'], visibility_setting: 'open') }
  let(:child_work) { index(Portfolio.new(title: ['A Machine for Learning'])) }
  let(:portfolio) { index(Portfolio.new(title: ['Primary Space'], member_ids: [file_set.id, child_work.id])) }

  def index(resource)
    saved = Hyrax.persister.save(resource:)
    Hyrax::SolrService.add(PortfolioIndexer.new(resource: saved).to_solr, commit: true)
    saved
  end

  before do
    Hyrax::Group.create(name: 'admin')
    sign_in admin
    allow_any_instance_of(ApplicationController).to receive(:show_page_theme).and_return('enact_show')
  end

  it 'renders the theme, with files and child works in separate sections' do
    get "/concern/portfolios/#{portfolio.id}"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('enact-show')
    expect(response.body).to include('Primary Space')

    # Parsed, not regex-sliced: files is the last pane, so a lookahead for the next pane
    # id fails and a greedy fallback swallows the sidebar and footer with it.
    doc = Nokogiri::HTML(response.body)
    files_pane = doc.at_css('#enact-pane-files').text
    items_pane = doc.at_css('#enact-pane-items').text

    expect(files_pane).to include('Bound portfolio.pdf')
    expect(files_pane).not_to include('A Machine for Learning')
    expect(items_pane).to include('A Machine for Learning')
    expect(items_pane).not_to include('Bound portfolio.pdf')
  end

  it 'lists an unreadable child work without exposing its description' do
    restricted = index(
      Portfolio.new(title: ['Private Child'], description: ['SECRET DESCRIPTION BODY'])
    )
    parent = index(Portfolio.new(title: ['Has a private child'], member_ids: [restricted.id]))

    # hide_private_items? is off by default, so an unreadable member is not filtered out
    # of the list at all. Hyku's own member row renders no description; without the read
    # gate the theme would print the body text of a work the viewer cannot open.
    allow_any_instance_of(::Ability).to receive(:can?).and_wrap_original do |original, action, subject|
      id = subject.respond_to?(:id) ? subject.id : subject
      action == :read && id.to_s == restricted.id.to_s ? false : original.call(action, subject)
    end

    get "/concern/portfolios/#{parent.id}"

    expect(response).to have_http_status(:ok)

    # The row is still listed, but Hyrax's link_name replaces an unreadable member's
    # title with the literal "Private", so that placeholder is what proves it rendered.
    items = Nokogiri::HTML(response.body).at_css('#enact-pane-items')
    expect(items.at_css('.enact-item-title').text.strip).to eq('Private')
    expect(items.text).not_to include('SECRET DESCRIPTION BODY')
  end

  it 'drops the files tab when the record holds no files of its own' do
    portfolio_without_files = index(Portfolio.new(title: ['Empty of files'], member_ids: [child_work.id]))

    get "/concern/portfolios/#{portfolio_without_files.id}"

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include('id="enact-pane-files"')
    expect(response.body).to include('id="enact-pane-items"')
  end
end
