# frozen_string_literal: true

require 'aws-sdk-cloudfront'

module HykuKnapsack
  module IiifCloudfrontCookies
    extend ActiveSupport::Concern

    class << self
      def signer
        @signer ||= Aws::CloudFront::CookieSigner.new(
          key_pair_id: ENV['IIIF_CF_KEY_PAIR_ID'],
          private_key: Base64.decode64(ENV['IIIF_CF_PRIVATE_KEY'])
        )
      end

      def base_url
        @base_url ||= begin
          uri = URI.parse(ENV.fetch('EXTERNAL_IIIF_URL', ''))
          "#{uri.scheme}://#{uri.host}"
                      rescue URI::InvalidURIError
                        ''
        end
      end

      def reset_memoized!
        @signer = nil
        @base_url = nil
      end
    end

    included do
      before_action :set_iiif_cloudfront_cookies, if: :iiif_cloudfront_configured?
    end

    private

    def set_iiif_cloudfront_cookies
      signed_cookies.each do |name, value|
        cookies[name] = {
          value:,
          domain: iiif_cookie_domain,
          secure: true,
          http_only: true,
          same_site: :none
        }
      end
    rescue OpenSSL::PKey::RSAError, ArgumentError => e
      Rails.logger.error("IiifCloudfrontCookies: failed to set cookies: #{e.message}")
    end

    def signed_cookies
      # Custom policy supports wildcard Resources so one cookie covers all image paths.
      policy = {
        "Statement" => [{
          "Resource" => "#{IiifCloudfrontCookies.base_url}/*",
          "Condition" => { "DateLessThan" => { "AWS:EpochTime" => 1.hour.from_now.to_i } }
        }]
      }.to_json
      IiifCloudfrontCookies.signer.signed_cookie(policy:)
    end

    def iiif_cloudfront_configured?
      ENV['IIIF_CF_KEY_PAIR_ID'].present? && ENV['IIIF_CF_PRIVATE_KEY'].present?
    end

    def iiif_cookie_domain
      parts = request.host.split('.')
      return request.host if parts.length < 2
      ".#{parts[-2]}.#{parts[-1]}"
    end
  end
end
