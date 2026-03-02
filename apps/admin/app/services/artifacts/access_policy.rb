module Artifacts
  class AccessPolicy
    def initialize(run:, request:, env: ENV)
      @run = run
      @request = request
      @env = env
    end

    def allowed?
      @run.succeeded? && token_authorized?
    end

    private

    def token_authorized?
      expected_token = @env["ADMIN_ARTIFACTS_TOKEN"].to_s
      return true if expected_token.empty?

      provided_token = bearer_token.presence || @request.headers["X-Admin-Token"].to_s.presence || @request.headers["X-Admin-Artifact-Token"].to_s
      ActiveSupport::SecurityUtils.secure_compare(provided_token, expected_token)
    rescue ArgumentError
      false
    end

    def bearer_token
      auth_header = @request.headers["Authorization"].to_s
      return nil unless auth_header.start_with?("Bearer ")

      auth_header.delete_prefix("Bearer ")
    end
  end
end
