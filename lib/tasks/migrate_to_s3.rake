# frozen_string_literal: true

namespace :enact do
  desc "Migrate FileSets from disk storage to the Valkyrie repository S3 bucket (Shrine). " \
       "Reads each disk-stored original file, uploads it to S3, updates file_identifier in " \
       "Postgres, and reindexes the FileSet so iiif_file_identifier_ss is populated. " \
       "Prerequisite: REPOSITORY_S3_STORAGE=true and REPOSITORY_S3_BUCKET configured. " \
       "Safe to re-run: already-migrated files are skipped. Set DRY_RUN=true to preview."
  task migrate_files_to_s3: :environment do
    abort "Set REPOSITORY_S3_STORAGE=true before running this task" unless ENV['REPOSITORY_S3_STORAGE'] == 'true'

    shrine_adapter = Valkyrie::StorageAdapter.find(:repository_s3)
    dry_run = ActiveModel::Type::Boolean.new.cast(ENV.fetch('DRY_RUN', 'false'))
    counts  = { migrated: 0, skipped: 0, errors: 0 }

    puts "Target bucket : #{ENV['REPOSITORY_S3_BUCKET']}"
    puts "Mode          : #{dry_run ? 'DRY RUN (no changes)' : 'LIVE'}"
    puts

    Account.find_each do |account|
      next if account.name == 'search'

      account.switch do
        puts "=== #{account.name} ==="

        Hyrax.query_service.find_all_of_model(model: Hyrax::FileSet).each do |file_set|
          original   = Hyrax.custom_queries.find_original_file(file_set: file_set)
          identifier = original&.file_identifier&.to_s

          if identifier.blank? || !identifier.start_with?('disk://')
            status = identifier&.start_with?('shrine://') ? 'S3 already' : 'no original'
            puts "  skip  #{file_set.id}  (#{status})"
            counts[:skipped] += 1
            next
          end

          puts "  #{dry_run ? 'would migrate' : 'migrating'}  #{file_set.id}  #{original.original_filename}"
          next if dry_run

          disk_file      = Hyrax.storage_adapter.find_by(id: original.file_identifier)
          new_file       = shrine_adapter.upload(file: disk_file,
                                                  original_filename: original.original_filename.to_s,
                                                  resource: file_set)
          original.file_identifier = new_file.id
          Hyrax.metadata_adapter.persister.save(resource: original)

          solr_doc = Hyrax::Indexers::FileSetIndexer.new(resource: file_set).generate_solr_document
          Hyrax::SolrService.add(solr_doc, commit: false)

          counts[:migrated] += 1
        rescue Valkyrie::StorageAdapter::FileNotFound, Valkyrie::Persistence::ObjectNotFoundError => e
          warn "  ERROR #{file_set.id}: #{e.message}"
          counts[:errors] += 1
        end

        Hyrax::SolrService.commit unless dry_run
      end
    end

    puts
    puts "Done: #{counts[:migrated]} #{dry_run ? 'would migrate' : 'migrated'}, " \
         "#{counts[:skipped]} skipped, #{counts[:errors]} errors"
    exit 1 if counts[:errors].positive?
  end
end
