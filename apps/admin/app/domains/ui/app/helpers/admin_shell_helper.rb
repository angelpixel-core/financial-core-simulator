module AdminShellHelper
  ADMIN_HEADER_BRAND_BY_ROLE = {
    "operator" => "OPERATOR WORKSPACE",
    "admin" => "ADMIN WORKSPACE",
    "viewer" => "ADMIN WORKSPACE"
  }.freeze

  def current_admin_account
    account_id = admin_shell_account_id
    return nil if account_id.blank?

    Account.find_by(id: account_id)
  end

  def admin_shell_account_email
    current_admin_account&.email.to_s.presence
  end

  def admin_shell_role
    Admin::SessionRoleResolver.call(current_admin_account)
  end

  def admin_shell_admin?
    admin_shell_role == "admin"
  end

  def admin_shell_operator?
    admin_shell_role == "operator"
  end

  def admin_shell_workspace_label
    ADMIN_HEADER_BRAND_BY_ROLE.fetch(admin_shell_role, ADMIN_HEADER_BRAND_BY_ROLE.fetch("viewer"))
  end

  private

  def admin_shell_account_id
    session["admin_account_id"] ||
      session[:admin_account_id] ||
      session["account_id"] ||
      session[:account_id]
  end
end
