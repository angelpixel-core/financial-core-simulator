module Admin
  class Authorization
    ROLE_ORDER = {
      "viewer" => 0,
      "operator" => 1,
      "admin" => 2
    }.freeze

    def initialize(request:, env: ENV)
      @request = request
      @env = env
    end

    def allow?(required_role: "viewer", token_key: "ADMIN_UI_TOKEN")
      allow_machine_or_session?(required_role: required_role, token_key: token_key)
    rescue ArgumentError
      false
    end

    def allow_admin_session?(required_role: "viewer")
      user = current_user
      return false unless user

      role_allowed?(user.fetch(:role), required_role)
    end

    def allow_machine_or_session?(required_role: "viewer", token_key: "ADMIN_UI_TOKEN")
      return true if allow_admin_session?(required_role: required_role)

      if token_key == "ADMIN_ARTIFACTS_TOKEN"
        allow_machine_artifact_token?(required_role: required_role)
      else
        allow_machine_ui_token?(required_role: required_role, token_key: token_key)
      end
    end

    def allow_machine_ui_token?(required_role: "viewer", token_key: "ADMIN_UI_TOKEN")
      return false unless machine_role_allowed?(required_role)

      expected_token = @env[token_key].to_s
      return true if expected_token.empty?

      provided_token = bearer_token.presence || @request.headers["X-Admin-Token"].to_s.presence
      return false if provided_token.blank?

      ActiveSupport::SecurityUtils.secure_compare(provided_token, expected_token)
    end

    def allow_machine_artifact_token?(required_role: "viewer")
      return false unless machine_role_allowed?(required_role)

      expected_token = @env["ADMIN_ARTIFACTS_TOKEN"].to_s
      return true if expected_token.empty?

      provided_token = bearer_token.presence || @request.headers["X-Admin-Artifact-Token"].to_s.presence
      return false if provided_token.blank?

      ActiveSupport::SecurityUtils.secure_compare(provided_token, expected_token)
    end

    private

    def current_user
      role = @request.headers["X-Admin-Role"].to_s.strip.downcase
      user = @request.headers["X-Admin-User"].to_s.strip
      return nil if role.empty? && user.empty?
      return nil unless ROLE_ORDER.key?(role)

      { id: user.presence || "header-user", role: role }
    end

    def role_allowed?(role, required_role)
      ROLE_ORDER.fetch(role, -1) >= ROLE_ORDER.fetch(required_role, 0)
    end

    def bearer_token
      auth_header = @request.headers["Authorization"].to_s
      return nil unless auth_header.start_with?("Bearer ")

      auth_header.delete_prefix("Bearer ")
    end

    def machine_role_allowed?(required_role)
      allowed_roles = %w[viewer operator]
      allowed_roles.include?(required_role)
    end
  end
end
