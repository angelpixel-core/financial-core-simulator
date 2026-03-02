module Artifacts
  class AccessPolicy
    def initialize(run:, request:, env: ENV)
      @run = run
      @request = request
      @env = env
    end

    def allowed?
      @run.succeeded? && authorization.allow?(required_role: "viewer", token_key: "ADMIN_ARTIFACTS_TOKEN")
    end

    private

    def authorization
      @authorization ||= Admin::Authorization.new(request: @request, env: @env)
    end
  end
end
