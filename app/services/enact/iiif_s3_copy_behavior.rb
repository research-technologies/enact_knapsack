# frozen_string_literal: true

require 'aws-sdk-s3'

module Enact
  module IiifS3CopyBehavior
    def self.prepend_features(base)
      super unless base.ancestors.include?(self)
    end

    class << self
      def bucket_name
        ENV.fetch('IIIF_S3_BUCKET', 'enact-iiif-images')
      end

      def configured?
        ENV['EXTERNAL_IIIF_URL'].present? && bucket_name.present?
      end

      def key_for(filename)
        sha1   = Digest::SHA1.file(filename).hexdigest
        prefix = ENV['IIIF_S3_FOLDER_PREFIX'].presence
        [prefix, sha1].compact.join('/')
      end

      def upload(filename)
        return unless configured?

        key = key_for(filename)
        Aws::S3::Resource.new.bucket(bucket_name).object(key).upload_file(filename)
        Rails.logger.info("IiifS3CopyBehavior: uploaded #{filename} to s3://#{bucket_name}/#{key}")
      end
    end

    def create_derivatives(filename)
      super
      Enact::IiifS3CopyBehavior.upload(filename)
    rescue Aws::S3::Errors::ServiceError, Errno::ENOENT, Errno::EACCES => e
      Rails.logger.error("IiifS3CopyBehavior: failed to copy to IIIF bucket: #{e.message}")
    end
  end
end
