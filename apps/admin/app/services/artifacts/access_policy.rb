module Artifacts
  class AccessPolicy
    def initialize(run:, request:, env: ENV)
      @run = run
      @request = request
      @env = env
    end

    def allowed?
      return false unless @run.succeeded?

      operator_session_allowed = authorization.allow_admin_session?(required_role: "operator")
      artifact_token_allowed = authorization.allow_machine_artifact_token?(required_role: "viewer")

      operator_session_allowed || artifact_token_allowed
    end

    private

    def authorization
      @authorization ||= Admin::Authorization.new(request: @request, env: @env)
    end
  end
end
