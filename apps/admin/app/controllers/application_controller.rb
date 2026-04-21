class ApplicationController < ActionController::Base
  include Rodauth::Rails::ControllerMethods
  include AdminShellHelper

  before_action :set_locale

  helper_method :current_admin_account,
    :admin_shell_account_email,
    :admin_shell_role,
    :admin_shell_admin?,
    :admin_shell_operator?,
    :admin_shell_workspace_label

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private

  def policy_user
    @policy_user ||= authorization.policy_actor(required_role: "viewer", token_key: "ADMIN_UI_TOKEN")
  end

  def authorize_policy!(policy_class, query, record: nil)
    policy = policy_class.new(policy_user, record)
    return if policy.public_send(query)

    handle_policy_unauthorized!
  end

  def handle_policy_unauthorized!
    if request.get? && request.format.html?
      redirect_to root_path
    else
      render plain: "Forbidden", status: :forbidden
    end
  end

  def set_locale
    selected = params[:locale].presence || session[:locale]
    locale = normalize_locale(selected)
    I18n.locale = locale
    session[:locale] = locale
  end

  def normalize_locale(value)
    return I18n.default_locale if value.blank?

    candidate = value.to_s.tr("-", "_").to_sym
    I18n.available_locales.include?(candidate) ? candidate : I18n.default_locale
  end

  def authorization
    @authorization ||= Admin::Authorization.new(request: request)
  end
end
