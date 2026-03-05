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
      user = current_user
      return role_allowed?(user.fetch(:role), required_role) if user

      expected_token = @env[token_key].to_s
      return true if expected_token.empty?

      provided_token = provided_token_for(token_key)
      return false if provided_token.blank?

      ActiveSupport::SecurityUtils.secure_compare(provided_token, expected_token)
    rescue ArgumentError
      false
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

    def provided_token_for(token_key)
      bearer_token.presence ||
        @request.headers["X-Admin-Token"].to_s.presence ||
        artifact_header_token_for(token_key)
    end

    def artifact_header_token_for(token_key)
      return nil unless token_key == "ADMIN_ARTIFACTS_TOKEN"

      @request.headers["X-Admin-Artifact-Token"].to_s.presence
    end
  end
end
