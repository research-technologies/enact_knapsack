# frozen_string_literal: true

module ApplicationControllerDecorator
  extend ActiveSupport::Concern

  prepended do
    before_action :set_current_user

    # Hyku's work show/manifest actions send `fresh_when` + `expires_in 1.hour,
    # public: true` for everyone. A signed-in page embeds a per-session CSRF
    # token, so a cached copy from an earlier session posts a stale token
    # (InvalidAuthenticityToken, e.g. on hyrax-pid's Mint DOI form).
    #
    # Fold the session's CSRF token into the ETag so a 304 is never served
    # across sessions...
    etag { session[:_csrf_token] if user_signed_in? }
    # ...and stop browsers/proxies reusing signed-in pages without revalidating.
    # Anonymous visitors keep Hyku's public caching.
    after_action :no_shared_cache_for_signed_in_users
  end

  private

  def set_current_user
    HykuKnapsack::Current.user = current_user
  end

  def no_shared_cache_for_signed_in_users
    return unless user_signed_in?

    response.cache_control.replace(private: true, no_cache: true)
  end
end

ApplicationController.prepend(ApplicationControllerDecorator)
