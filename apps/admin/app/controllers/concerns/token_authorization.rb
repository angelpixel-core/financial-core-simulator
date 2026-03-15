module TokenAuthorization
  private

  def token_authorized_for?(env_key)
    expected_token = ENV[env_key].to_s
    return true if expected_token.empty?

    provided_token = bearer_token.presence ||
      request.headers["X-Admin-Token"].to_s.presence ||
      request.headers["X-Admin-Artifact-Token"].to_s
    ActiveSupport::SecurityUtils.secure_compare(provided_token, expected_token)
  rescue ArgumentError
    false
  end

  def bearer_token
    auth_header = request.headers["Authorization"].to_s
    return nil unless auth_header.start_with?("Bearer ")

    auth_header.delete_prefix("Bearer ")
  end
end
