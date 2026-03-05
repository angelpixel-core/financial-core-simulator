module AdminUiAuthorizable
  private

  def authorize_admin_ui!(required_role: "viewer", token_key: "ADMIN_UI_TOKEN")
    auth = Admin::Authorization.new(request: request)
    return if auth.allow?(required_role: required_role, token_key: token_key)

    render plain: "Forbidden", status: :forbidden
  end
end
