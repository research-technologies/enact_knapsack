# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Enact::TenantConfig do
  let(:dir) { Pathname.new(Dir.mktmpdir) }
  let(:png) { Base64.decode64('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==') }

  after { FileUtils.remove_entry(dir) }

  def attach_favicon(site)
    Tempfile.create(['favicon', '.png']) do |file|
      file.binmode
      file.write(png)
      file.flush
      File.open(file.path) { |f| site.favicon = f }
      site.save!
    end
  end

  describe '#export and #import' do
    before do
      Site.instance.update!(institution_name: 'Enact Demo', home_theme: 'enact_home', show_theme: 'enact_show',
                            search_theme: 'gallery_view', available_works: %w[Portfolio PortfolioEvent])
      ContentBlock.find_or_initialize_by(name: 'home_text').update!(value: '<p>Welcome</p>')
      ContentBlock.find_or_initialize_by(name: 'custom_css_block').update!(value: '.a { color: red }')
      Hyrax::Feature.find_or_initialize_by(key: 'deposit_wizard').update!(enabled: true)
      Hyrax::Feature.find_or_initialize_by(key: 'hls_streaming').update!(enabled: false)
    end

    it 'writes the manifest and returns it' do
      manifest = described_class.new(dir).export

      expect(JSON.parse(dir.join('config.json').read)).to eq(manifest)
      expect(manifest['site']).to include('institution_name' => 'Enact Demo', 'home_theme' => 'enact_home',
                                          'available_works' => %w[Portfolio PortfolioEvent])
      expect(manifest['content_blocks']).to include('home_text' => '<p>Welcome</p>')
      expect(manifest['features']).to include('deposit_wizard' => true, 'hls_streaming' => false)
      expect(manifest['uploads']).to eq({})
      expect(manifest['account_settings']).to eq({})
      expect(dir.join('uploads')).not_to exist
    end

    it 'restores everything into a blank site, including uploads' do
      attach_favicon(Site.instance)
      source_manifest = described_class.new(dir).export
      expect(source_manifest['uploads']).to match('favicon' => a_string_ending_with('.png'))
      expect(dir.join('uploads', source_manifest['uploads']['favicon'])).to exist

      Site.instance.update!(remove_favicon: '1', institution_name: nil, home_theme: nil, show_theme: nil, search_theme: nil)
      expect(Site.instance.reload.favicon).to be_blank
      ContentBlock.delete_all
      Hyrax::Feature.delete_all
      expect(Flipflop::FeatureCache.current).to receive(:clear!)

      described_class.new(dir).import

      site = Site.instance.reload
      expect(site).to have_attributes(institution_name: 'Enact Demo', home_theme: 'enact_home',
                                      show_theme: 'enact_show', search_theme: 'gallery_view',
                                      available_works: %w[Portfolio PortfolioEvent])
      expect(site.favicon).to be_present
      expect(ContentBlock.find_by(name: 'home_text').value).to eq('<p>Welcome</p>')
      expect(Hyrax::Feature.find_by(key: 'deposit_wizard').enabled).to be true
      expect(Hyrax::Feature.find_by(key: 'hls_streaming').enabled).to be false
    end

    it 'is safe to re-run' do
      described_class.new(dir).export
      ContentBlock.find_by(name: 'home_text').update!(value: 'changed')

      expect { 2.times { described_class.new(dir).import } }.not_to change(ContentBlock, :count)
      expect(ContentBlock.find_by(name: 'home_text').value).to eq('<p>Welcome</p>')
    end
  end

  describe 'account settings' do
    let(:account) { create(:account) }

    before do
      Site.instance.update!(account:)
      account.update!(allow_downloads: false, hidden_index_fields: 'title, creator', contact_email: 'demo@example.com',
                      bulkrax_field_mappings: '{"Bulkrax::BagitParser":{}}')
    end

    it 'exports only the allowlisted settings' do
      settings = described_class.new(dir).export['account_settings']

      expect(settings.keys).to match_array(described_class::ACCOUNT_SETTINGS)
      expect(settings).to include('allow_downloads' => false, 'hidden_index_fields' => 'title, creator')
      expect(JSON.parse(settings['bulkrax_field_mappings'])).to eq('Bulkrax::BagitParser' => {})
    end

    it 'imports them without touching contact emails' do
      # Changing a notification setting schedules jobs inside the account's tenant, which has no schema here.
      site = Site.instance
      site.account = account
      allow(Site).to receive(:instance).and_return(site)
      allow(Apartment::Tenant).to receive(:switch).and_yield
      allow(account).to receive(:find_or_schedule_jobs)
      described_class.new(dir).export
      account.update!(allow_downloads: true, hidden_index_fields: 'title', contact_email: 'prod@example.com')

      described_class.new(dir).import

      expect(account.reload).to have_attributes(allow_downloads: false, hidden_index_fields: 'title, creator',
                                                contact_email: 'prod@example.com')
    end

    it 'raises when the destination tenant has no account' do
      described_class.new(dir).export
      Site.instance.update!(account: nil)

      expect { described_class.new(dir).import }.to raise_error(ArgumentError, /no Account/)
    end

    it 'skips settings when the bundle has none' do
      described_class.new(dir).export
      manifest = JSON.parse(dir.join('config.json').read).except('account_settings')
      dir.join('config.json').write(JSON.generate(manifest))

      expect { described_class.new(dir).import }.not_to raise_error
    end
  end

  describe '.export_tenant and .import_tenant' do
    let(:instance) { instance_double(described_class, export: { 'a' => 1 }, import: { 'b' => 2 }) }

    before { allow(described_class).to receive(:new).with(dir).and_return(instance) }

    it 'switches to the tenant before exporting' do
      expect(AccountElevator).to receive(:switch!).with('demo.example.com').ordered
      expect(instance).to receive(:export).ordered

      expect(described_class.export_tenant(cname: 'demo.example.com', dir:)).to eq('a' => 1)
    end

    it 'switches to the tenant before importing' do
      expect(AccountElevator).to receive(:switch!).with('new.example.com').ordered
      expect(instance).to receive(:import).ordered

      expect(described_class.import_tenant(cname: 'new.example.com', dir:)).to eq('b' => 2)
    end
  end
end
