module AdminShellHelper
  def current_admin_account
    account_id = admin_shell_account_id
    return nil if account_id.blank?

    Account.find_by(id: account_id)
  end

  def admin_shell_account_email
    current_admin_account&.email.to_s.presence
  end

  private

  def admin_shell_account_id
    session["admin_account_id"] ||
      session[:admin_account_id] ||
      session["account_id"] ||
      session[:account_id]
  end
end
