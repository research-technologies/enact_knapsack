# frozen_string_literal: true

module IiifAccessCookie
  extend ActiveSupport::Concern

  included do
    after_action :set_iiif_access_cookie
  end

  private

  def set_iiif_access_cookie
    return unless ENV['IIIF_HMAC_SECRET'].present?

    expiry = 1.hour.from_now.to_i
    hmac = OpenSSL::HMAC.hexdigest('SHA256', ENV['IIIF_HMAC_SECRET'], expiry.to_s)

    cookies[:iiif_access] = {
      value: "#{expiry}.#{hmac}",
      domain: iiif_cookie_domain,
      secure: request.ssl?,
      httponly: true,
      same_site: :lax,
      expires: 1.hour.from_now
    }
  end

  def iiif_cookie_domain
    # Use explicit override if set, otherwise derive from request host:
    # app is on e.g. tenant.enacthyku.com, cookie must cover iiif.enacthyku.com too,
    # so we set it on the top two domain labels (.enacthyku.com).
    ENV['IIIF_COOKIE_DOMAIN'] || begin
      parts = request.host.split('.')
      parts.length >= 2 ? ".#{parts[-2..].join('.')}" : request.host
    end
  end
end
