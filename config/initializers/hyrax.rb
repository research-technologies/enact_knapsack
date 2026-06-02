# frozen_string_literal: true

# Use this to override any Hyrax configuration from the Knapsack

Rails.application.config.after_initialize do
  Hyrax.config do |config|
    config.flexible = ActiveModel::Type::Boolean.new.cast(ENV.fetch('HYRAX_FLEXIBLE', 'false'))

    # Prepend to ensure knapsack profile is checked before the host app's profiles.
    config.schema_loader_config_search_paths.unshift(HykuKnapsack::Engine.root) \
      if config.respond_to?(:schema_loader_config_search_paths)

    config.iiif_image_url_builder = lambda do |file_id, base_url, size, _format|
      if ENV['EXTERNAL_IIIF_URL'].present?
        external_base = ENV['EXTERNAL_IIIF_URL'].sub(/\Ahttps?:\/\//, '')
        "https://#{external_base}/#{file_id}/full/#{size}/0/default.jpg"
      else
        # Comment this next line to allow universal viewer to work in development
        # Issue with Hyrax v 2.9.0 where IIIF has mixed content error when running with SSL enabled
        # See Samvera Slack thread https://samvera.slack.com/archives/C0F9JQJDQ/p1596718417351200?thread_ts=1596717896.350700&cid=C0F9JQJDQ
        base_url = base_url.sub(/\Ahttp:/, 'https:')
        Riiif::Engine.routes.url_helpers.image_url(file_id, host: base_url, size:)
      end
    end

    config.iiif_info_url_builder = lambda do |file_id, base_url|
      if ENV['EXTERNAL_IIIF_URL'].present?
        external_base = ENV['EXTERNAL_IIIF_URL'].sub(/\Ahttps?:\/\//, '')
        "https://#{external_base}/#{file_id}"
      else
        uri = Riiif::Engine.routes.url_helpers.info_url(file_id, host: base_url)
        uri = uri.sub(%r{/info\.json\Z}, '')
        # Comment this next line to allow universal viewer to work in development
        # Issue with Hyrax v 2.9.0 where IIIF has mixed content error when running with SSL enabled
        # See Samvera Slack thread https://samvera.slack.com/archives/C0F9JQJDQ/p1596718417351200?thread_ts=1596717896.350700&cid=C0F9JQJDQ
        uri.sub(/\Ahttp:/, 'https:')
      end
    end
  end
end
