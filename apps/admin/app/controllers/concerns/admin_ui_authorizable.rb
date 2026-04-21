module AdminUiAuthorizable
  private

  def authorize_admin_ui!(required_role: "viewer", token_key: "ADMIN_UI_TOKEN")
    authorize_machine_or_session!(required_role: required_role, token_key: token_key)
  end

  def authorize_admin_session!(required_role: "viewer")
    auth = Admin::Authorization.new(request: request)
    return if allow_admin_session_gate?(auth, required_role: required_role)

    handle_unauthorized_access!
  end

  def authorize_machine_or_session!(required_role: "viewer", token_key: "ADMIN_UI_TOKEN")
    auth = Admin::Authorization.new(request: request)
    return if allow_machine_or_session_gate?(auth, required_role: required_role, token_key: token_key)

    handle_unauthorized_access!
  end

  def authorize_admin_session_viewer!
    authorize_admin_session!(required_role: "viewer")
  end

  def authorize_admin_session_operator!
    authorize_admin_session!(required_role: "operator")
  end

  def authorize_admin_session_admin!
    authorize_admin_session!(required_role: "admin")
  end

  def authorize_machine_or_session_viewer!(token_key: "ADMIN_UI_TOKEN")
    authorize_machine_or_session!(required_role: "viewer", token_key: token_key)
  end

  def authorize_machine_or_session_operator!(token_key: "ADMIN_UI_TOKEN")
    authorize_machine_or_session!(required_role: "operator", token_key: token_key)
  end

  def authorize_machine_or_session_admin!(token_key: "ADMIN_UI_TOKEN")
    authorize_machine_or_session!(required_role: "admin", token_key: token_key)
  end

  def authorize_with_policy!(policy_class:, query:, record:, required_role: "viewer", gate: :session,
    token_key: "ADMIN_UI_TOKEN")
    case gate
    when :session
      authorize_admin_session!(required_role: required_role)
    when :machine_or_session
      authorize_machine_or_session!(required_role: required_role, token_key: token_key)
    else
      raise ArgumentError, "Unsupported authorization gate: #{gate}"
    end

    return if performed?

    authorize_policy!(policy_class, query, record: record)
  end

  def allow_admin_session_gate?(auth, required_role:)
    return auth.allow_admin_session?(required_role: required_role) if auth.respond_to?(:allow_admin_session?)

    auth.allow?(required_role: required_role, token_key: "ADMIN_UI_TOKEN")
  end

  def allow_machine_or_session_gate?(auth, required_role:, token_key:)
    if auth.respond_to?(:allow_machine_or_session?)
      return auth.allow_machine_or_session?(required_role: required_role,
        token_key: token_key)
    end

    auth.allow?(required_role: required_role, token_key: token_key)
  end

  def handle_unauthorized_access!
    if request.get? && request.format.html?
      redirect_to root_path
    else
      render plain: "Forbidden", status: :forbidden
    end
  end
end
