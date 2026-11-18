# frozen_string_literal: true

module Enact
  # Copies a tenant's look-and-feel to another tenant through a directory bundle:
  # site settings, content blocks, feature flags, uploaded site images, the names and
  # descriptions of the default groups, and a behavioural subset of the Account settings
  # (never contact emails, analytics ids or private settings).
  # #export and #import act on the current tenant; the .export_tenant / .import_tenant
  # entry points switch to a tenant by cname first.
  class TenantConfig
    MANIFEST = 'config.json'
    SITE_ATTRIBUTES = %w[
      application_name institution_name institution_name_full contact_email directory_image_alt_text
      home_theme show_theme search_theme available_works
    ].freeze
    SITE_UPLOADS = %w[banner_image logo_image directory_image default_collection_image default_work_image favicon].freeze
    GROUP_ATTRIBUTES = %w[humanized_name description].freeze
    ACCOUNT_SETTINGS = %w[
      allow_downloads batch_email_notifications depositor_email_notifications bulkrax_field_mappings
      file_size_limit hidden_index_fields solr_max_results solr_rows_per_request
    ].freeze

    def self.export_tenant(cname:, dir:)
      AccountElevator.switch!(cname)
      new(dir).export
    end

    def self.import_tenant(cname:, dir:)
      AccountElevator.switch!(cname)
      new(dir).import
    end

    def initialize(dir)
      @dir = Pathname.new(dir)
    end

    # @return [Hash] the manifest written to the bundle
    def export
      @dir.mkpath
      manifest = {
        'site' => site.attributes.slice(*SITE_ATTRIBUTES),
        'uploads' => export_uploads,
        'content_blocks' => ContentBlock.pluck(:name, :value).to_h,
        'features' => Hyrax::Feature.pluck(:key, :enabled).to_h,
        'account_settings' => export_account_settings,
        'groups' => export_groups
      }
      @dir.join(MANIFEST).write(JSON.pretty_generate(manifest))
      manifest
    end

    # @return [Hash] the manifest that was applied
    def import
      manifest = JSON.parse(@dir.join(MANIFEST).read)
      import_site(manifest)
      import_content_blocks(manifest['content_blocks'])
      import_features(manifest['features'])
      import_account_settings(manifest['account_settings'])
      import_groups(manifest['groups'])
      Flipflop::FeatureCache.current.clear!
      manifest
    end

    private

    # Site.instance re-queries on every call, so memoize: assignments and #save! must hit one object.
    def site
      @site ||= Site.instance
    end

    def export_uploads
      uploads_dir = @dir.join('uploads')
      SITE_UPLOADS.each_with_object({}) do |name, files|
        file = site.public_send(name)
        next if file.blank?

        uploads_dir.mkpath
        FileUtils.cp(file.path, uploads_dir.join(File.basename(file.path)))
        files[name] = File.basename(file.path)
      end
    end

    def import_site(manifest)
      site.assign_attributes(manifest['site'])
      manifest['uploads'].each do |name, filename|
        File.open(@dir.join('uploads', filename)) { |file| site.public_send("#{name}=", file) }
      end
      site.save!
    end

    def import_content_blocks(blocks)
      blocks.each do |name, value|
        ContentBlock.find_or_initialize_by(name:).update!(value:)
      end
    end

    # RolesService bakes I18n.t into a constant at class load, so a tenant created while translations
    # are not yet loaded stores "Translation missing: ..." as its default groups' names; never copy those.
    def usable_group_value?(value)
      value.present? && !value.start_with?('Translation missing')
    end

    def export_groups
      default_names = RolesService::DEFAULT_HYRAX_GROUPS_WITH_ATTRIBUTES.keys.map(&:to_s)
      Hyrax::Group.where(name: default_names).to_h do |group|
        [group.name, group.slice(*GROUP_ATTRIBUTES).select { |_, value| usable_group_value?(value) }]
      end
    end

    def import_groups(groups)
      groups&.each do |name, attributes|
        Hyrax::Group.find_by(name:)&.update!(attributes)
      end
    end

    def export_account_settings
      return {} unless site.account

      ACCOUNT_SETTINGS.index_with { |name| site.account.public_send(name) }
    end

    def import_account_settings(settings)
      return if settings.blank?
      raise ArgumentError, 'Tenant has no Account to apply settings to' unless site.account

      site.account.update!(settings)
    end

    def import_features(features)
      features.each do |key, enabled|
        Hyrax::Feature.find_or_initialize_by(key:).update!(enabled:)
      end
    end
  end
end
