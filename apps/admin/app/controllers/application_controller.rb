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
    account = current_admin_account
    if account.present?
      return {
        id: account.id.to_s,
        role: admin_shell_role
      }
    end

    role = request.headers["X-Admin-Role"].to_s.strip.downcase
    user = request.headers["X-Admin-User"].to_s.strip
    if Admin::Authorization::ROLE_ORDER.key?(role)
      return {
        id: user.presence || "header-user",
        role: role
      }
    end

    return machine_policy_user if machine_policy_user_allowed?

    nil
  end

  def machine_policy_user_allowed?
    auth = Admin::Authorization.new(request: request)
    auth.allow_machine_ui_token?(required_role: "viewer")
  rescue
    false
  end

  def machine_policy_user
    {
      id: "machine-user",
      role: "operator"
    }
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
end
