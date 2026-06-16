# frozen_string_literal: true

IiifBackfillConfig = Struct.new(:files, :bucket, :bucket_name, :dry_run, :force)

namespace :iiif do
  desc "Backfill existing EFS files into the IIIF S3 bucket. " \
       "Safe to re-run: existing objects are skipped by default. " \
       "Set FORCE=true to overwrite. Set DRY_RUN=true to preview without uploading."
  task backfill: :environment do
    iiif_backfill_validate
    config = iiif_backfill_config
    iiif_backfill_print_summary(config)
    iiif_backfill_process(config)
  end
end

def iiif_backfill_validate
  base_path = Rails.root.join('storage', 'files')
  abort "storage/files not found at #{base_path}" unless base_path.exist?
  abort "IIIF S3 not configured (EXTERNAL_IIIF_URL missing)" unless Enact::IiifS3CopyBehavior.configured?
end

def iiif_backfill_config
  bucket_name = Enact::IiifS3CopyBehavior.bucket_name
  dry_run = ActiveModel::Type::Boolean.new.cast(ENV.fetch('DRY_RUN', 'false'))
  force   = ActiveModel::Type::Boolean.new.cast(ENV.fetch('FORCE', 'false'))
  bucket  = Aws::S3::Resource.new.bucket(bucket_name)
  files   = Pathname.glob(Rails.root.join('storage', 'files', '**', '*')).select(&:file?)
  IiifBackfillConfig.new(files, bucket, bucket_name, dry_run, force)
end

def iiif_backfill_print_summary(config)
  mode = if config.dry_run
           'DRY RUN'
         else
           (config.force ? 'force overwrite' : 'skip existing')
         end
  puts "Bucket:  s3://#{config.bucket_name}"
  puts "Prefix:  #{ENV['IIIF_S3_FOLDER_PREFIX'].presence || '(none)'}"
  puts "Files:   #{config.files.count}"
  puts "Mode:    #{mode}"
  puts
end

def iiif_backfill_skip?(_path, key, config)
  !config.force && !config.dry_run && config.bucket.object(key).exists?
end

def iiif_backfill_upload(path, label, key, config)
  if config.dry_run
    puts "#{label} would upload #{path.basename} → s3://#{config.bucket_name}/#{key}"
    return :uploaded
  end
  Enact::IiifS3CopyBehavior.upload(path.to_s)
  puts "#{label} uploaded #{path.basename} → s3://#{config.bucket_name}/#{key}"
  :uploaded
end

def iiif_backfill_process_file(path, i, config)
  label = "[#{i + 1}/#{config.files.count}]"
  key   = Enact::IiifS3CopyBehavior.key_for(path.to_s)
  if iiif_backfill_skip?(path, key, config)
    puts "#{label} skip     #{key} (already exists)"
    return :skipped
  end
  iiif_backfill_upload(path, label, key, config)
end

def iiif_backfill_process(config)
  counts = { uploaded: 0, skipped: 0, errors: 0 }
  config.files.each_with_index do |path, i|
    counts[iiif_backfill_process_file(path, i, config)] += 1
  rescue Aws::S3::Errors::ServiceError, Errno::ENOENT, Errno::EACCES => e
    warn "[#{i + 1}/#{config.files.count}] ERROR    #{path.basename}: #{e.message}"
    counts[:errors] += 1
  end
  puts
  puts "Done: #{counts[:uploaded]} #{config.dry_run ? 'would upload' : 'uploaded'}, #{counts[:skipped]} skipped, #{counts[:errors]} errors"
  exit 1 if counts[:errors].positive?
end
