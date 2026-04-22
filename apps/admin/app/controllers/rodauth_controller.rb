class RodauthController < ApplicationController
  # Used by Rodauth for rendering views, CSRF protection, running any
  # registered action callbacks and rescue handlers, instrumentation etc.

  # Controller callbacks and rescue handlers will run around Rodauth endpoints.
  # before_action :verify_captcha, only: :login, if: -> { request.post? }
  # rescue_from("SomeError") { |exception| ... }

  # Layout can be changed for all Rodauth pages or only certain pages.
  # layout "authentication"
  # layout -> do
  #   case rodauth.current_route
  #   when :login, :create_account, :verify_account, :verify_account_resend,
  #        :reset_password, :reset_password_request
  #     "authentication"
  #   else
  #     "application"
  #   end
  # end
  layout :rodauth_layout
  before_action :redirect_logout_get_request
  before_action :enforce_login_abuse_protection

  private

  def redirect_logout_get_request
    return unless request.get? && rodauth.current_route == :logout

    redirect_to rodauth.login_path
  end

  def enforce_login_abuse_protection
    return unless rodauth.current_route == :login && request.post?

    Admin::Demo::AbuseProtection.enforce_login!(request: request)
  rescue Admin::Demo::AbuseProtection::LimitExceeded => e
    if request.format.json?
      render json: {code: e.code, message: e.message}, status: e.http_status
      return
    end

    redirect_to rodauth.login_path, alert: e.message
  end

  def rodauth_layout
    return "authentication" if rodauth.current_route == :login

    "application"
  end
end
