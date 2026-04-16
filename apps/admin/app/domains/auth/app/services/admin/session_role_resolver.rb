module Admin
  class SessionRoleResolver
    ROLE_BY_EMAIL = {
      "ops@example.com" => "operator",
      "admin@example.com" => "admin"
    }.freeze

    DEFAULT_ROLE = "viewer"

    def self.call(account_or_email, account_roles_repository: Admin::AccessControl::AccountRoles::Repository.new)
      if account_or_email.respond_to?(:id) && account_or_email.id.present?
        role = account_roles_repository.role_for_account(account_or_email)
        return role if role.present?
      end

      email = extract_email(account_or_email)
      return DEFAULT_ROLE if email.blank?

      ROLE_BY_EMAIL.fetch(email, DEFAULT_ROLE)
    end

    def self.extract_email(account_or_email)
      raw = if account_or_email.respond_to?(:email)
        account_or_email.email
      else
        account_or_email
      end

      raw.to_s.strip.downcase
    end
    private_class_method :extract_email
  end
end
