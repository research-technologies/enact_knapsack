# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'enact:tenant_config rake tasks' do
  let(:manifest) { { 'content_blocks' => { 'a' => 'x', 'b' => 'y' }, 'features' => { 'f' => true }, 'uploads' => { 'favicon' => 'f.png' } } }

  before do
    Rake::Task.define_task(:environment)
    Rake.application.rake_require('tasks/enact_tenant_config', [HykuKnapsack::Engine.root.join('lib').to_s])
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('TENANT').and_return('demo.example.com')
    allow(ENV).to receive(:fetch).with('DIR').and_return('/tmp/bundle')
  end

  it 'exports a tenant and reports counts' do
    expect(Enact::TenantConfig).to receive(:export_tenant).with(cname: 'demo.example.com', dir: '/tmp/bundle').and_return(manifest)

    expect { Rake::Task['enact:tenant_config:export'].execute }
      .to output(%r{Exported 2 content blocks, 1 features, 1 site images to /tmp/bundle}).to_stdout
  end

  it 'imports a bundle into a tenant and reports counts' do
    expect(Enact::TenantConfig).to receive(:import_tenant).with(cname: 'demo.example.com', dir: '/tmp/bundle').and_return(manifest)

    expect { Rake::Task['enact:tenant_config:import'].execute }
      .to output(/Imported 2 content blocks, 1 features, 1 site images into demo.example.com/).to_stdout
  end
end
