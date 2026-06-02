# frozen_string_literal: true

module IiifAccessCookie
  extend ActiveSupport::Concern

  included do
    after_action :set_iiif_access_cookie
  end

  private

  def set_iiif_access_cookie
    return unless iiif_cloudfront_configured?

    resource = "https://#{ENV['IIIF_COOKIE_DOMAIN'].delete_prefix('.')}/*"
    expiry   = 1.hour.from_now

    signer = Aws::CloudFront::CookieSigner.new(
      key_pair_id:  ENV['IIIF_CF_KEY_PAIR_ID'],
      private_key:  ENV['IIIF_CF_PRIVATE_KEY']
    )

    signed = signer.signed_cookie(resource, expires: expiry.to_i)

    signed.each do |name, value|
      cookies[name] = {
        value:     value,
        domain:    ENV.fetch('IIIF_COOKIE_DOMAIN', '.enacthyku.com'),
        secure:    request.ssl?,
        httponly:  true,
        same_site: :lax,
        expires:   expiry
      }
    end
  end

  def iiif_cloudfront_configured?
    ENV['IIIF_CF_KEY_PAIR_ID'].present? && ENV['IIIF_CF_PRIVATE_KEY'].present?
  end
end
