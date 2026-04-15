class ApplicationPolicy
  ROLE_ORDER = Admin::Authorization::ROLE_ORDER

  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def admin?
    role == "admin"
  end

  def operator?
    allow_role?("operator")
  end

  def viewer?
    allow_role?("viewer")
  end

  private

  def role
    user&.fetch(:role, nil).to_s
  end

  def allow_role?(required_role)
    return false unless ROLE_ORDER.key?(role)
    return false unless ROLE_ORDER.key?(required_role)

    ROLE_ORDER.fetch(role) >= ROLE_ORDER.fetch(required_role)
  end
end
