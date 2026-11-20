# frozen_string_literal: true

namespace :enact do
  namespace :tenant_config do
    desc 'Export a tenant\'s look-and-feel (site settings, content blocks, features, site images). TENANT=<cname> DIR=<path>'
    task export: :environment do
      manifest = Enact::TenantConfig.export_tenant(cname: ENV.fetch('TENANT'), dir: ENV.fetch('DIR'))
      puts "Exported #{manifest['content_blocks'].size} content blocks, #{manifest['features'].size} features, " \
           "#{manifest['uploads'].size} site images to #{ENV.fetch('DIR')}"
    end

    desc 'Apply an exported bundle to a tenant. Safe to re-run. TENANT=<cname> DIR=<path>'
    task import: :environment do
      manifest = Enact::TenantConfig.import_tenant(cname: ENV.fetch('TENANT'), dir: ENV.fetch('DIR'))
      puts "Imported #{manifest['content_blocks'].size} content blocks, #{manifest['features'].size} features, " \
           "#{manifest['uploads'].size} site images into #{ENV.fetch('TENANT')}"
    end
  end
end
