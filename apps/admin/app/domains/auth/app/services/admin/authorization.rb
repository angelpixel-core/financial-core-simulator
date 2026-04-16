module Admin
  class Authorization
    ROLE_ORDER = {
      'viewer' => 0,
      'operator' => 1,
      'admin' => 2
    }.freeze

    def initialize(
      request:,
      env: ENV,
      account_roles_repository: Admin::AccessControl::AccountRoles::Repository.new,
      audit_log_repository: Admin::AccessControl::AuditLog::Repository.new,
      authz_context_adapter: nil
    )
      @request = request
      @env = env
      @account_roles_repository = account_roles_repository
      @audit_log_repository = audit_log_repository
      @authz_context_adapter = authz_context_adapter || Admin::AccessControl::AuthzContextAdapter.new(request: request)
    end

    def allow?(required_role: 'viewer', token_key: 'ADMIN_UI_TOKEN')
      allow_machine_or_session?(required_role: required_role, token_key: token_key)
    rescue ArgumentError
      audit_decision!(
        action: 'authorization.allow',
        outcome: 'deny',
        required_role: required_role,
        role: nil,
        account: nil,
        gate: 'machine_or_session',
        token_key: token_key,
        context: { reason: 'argument_error' }
      )
      false
    end

    def allow_admin_session?(required_role: 'viewer')
      user = current_user
      return audit_session_decision(false, required_role: required_role, user: nil) unless user

      allowed = role_allowed?(user.fetch(:role), required_role)
      audit_session_decision(allowed, required_role: required_role, user: user)
    end

    def allow_machine_or_session?(required_role: 'viewer', token_key: 'ADMIN_UI_TOKEN')
      return true if allow_admin_session?(required_role: required_role)

      if token_key == 'ADMIN_ARTIFACTS_TOKEN'
        allow_machine_artifact_token?(required_role: required_role)
      else
        allow_machine_ui_token?(required_role: required_role, token_key: token_key)
      end
    end

    def allow_machine_ui_token?(required_role: 'viewer', token_key: 'ADMIN_UI_TOKEN')
      unless machine_role_allowed?(required_role)
        return audit_machine_decision(false, required_role: required_role,
                                             token_key: token_key)
      end

      expected_token = @env[token_key].to_s
      return audit_machine_decision(true, required_role: required_role, token_key: token_key) if expected_token.empty?

      provided_token = bearer_token.presence || @request.headers['X-Admin-Token'].to_s.presence
      return audit_machine_decision(false, required_role: required_role, token_key: token_key) if provided_token.blank?

      allowed = ActiveSupport::SecurityUtils.secure_compare(provided_token, expected_token)
      audit_machine_decision(allowed, required_role: required_role, token_key: token_key)
    end

    def allow_machine_artifact_token?(required_role: 'viewer')
      unless machine_role_allowed?(required_role)
        return audit_machine_decision(false, required_role: required_role,
                                             token_key: 'ADMIN_ARTIFACTS_TOKEN')
      end

      expected_token = @env['ADMIN_ARTIFACTS_TOKEN'].to_s
      if expected_token.empty?
        return audit_machine_decision(true, required_role: required_role,
                                            token_key: 'ADMIN_ARTIFACTS_TOKEN')
      end

      provided_token = bearer_token.presence || @request.headers['X-Admin-Artifact-Token'].to_s.presence
      if provided_token.blank?
        return audit_machine_decision(false, required_role: required_role,
                                             token_key: 'ADMIN_ARTIFACTS_TOKEN')
      end

      allowed = ActiveSupport::SecurityUtils.secure_compare(provided_token, expected_token)
      audit_machine_decision(allowed, required_role: required_role, token_key: 'ADMIN_ARTIFACTS_TOKEN')
    end

    private

    def current_user
      session_account = account_from_session
      return session_account if session_account

      role = @request.headers['X-Admin-Role'].to_s.strip.downcase
      user = @request.headers['X-Admin-User'].to_s.strip
      return nil if role.empty? && user.empty?
      return nil unless ROLE_ORDER.key?(role)

      { id: user.presence || 'header-user', role: role, account: nil }
    end

    def account_from_session
      account_id = session_account_id
      return nil if account_id.blank?

      account = Account.find_by(id: account_id)
      return nil unless account

      role = Admin::SessionRoleResolver.call(account)
      role = 'viewer' unless ROLE_ORDER.key?(role)

      { id: account.id.to_s, role: role, account: account }
    end

    def session_account_id
      session = @request.session

      session['admin_account_id'] ||
        session[:admin_account_id] ||
        session['account_id'] ||
        session[:account_id]
    end

    def role_allowed?(role, required_role)
      @account_roles_repository.role_allowed?(actual_role: role, required_role: required_role)
    end

    def bearer_token
      auth_header = @request.headers['Authorization'].to_s
      return nil unless auth_header.start_with?('Bearer ')

      auth_header.delete_prefix('Bearer ')
    end

    def machine_role_allowed?(required_role)
      allowed_roles = %w[viewer operator]
      allowed_roles.include?(required_role)
    end

    def audit_session_decision(allowed, required_role:, user:)
      audit_decision!(
        action: 'authorization.session',
        outcome: allowed ? 'allow' : 'deny',
        required_role: required_role,
        role: user&.fetch(:role, nil),
        account: user&.fetch(:account, nil),
        gate: 'session'
      )
      allowed
    end

    def audit_machine_decision(allowed, required_role:, token_key:)
      audit_decision!(
        action: 'authorization.machine',
        outcome: allowed ? 'allow' : 'deny',
        required_role: required_role,
        role: 'machine',
        account: nil,
        gate: 'machine',
        token_key: token_key
      )
      allowed
    end

    def audit_decision!(action:, outcome:, required_role:, role:, account:, gate:, token_key: nil, context: {})
      authz_context = @authz_context_adapter.call(
        account: account,
        role: role,
        required_role: required_role,
        gate: gate,
        token_key: token_key
      )

      @audit_log_repository.record!(
        action: action,
        outcome: outcome,
        account: account,
        role: role,
        required_role: required_role,
        context: authz_context.merge(context)
      )
    rescue StandardError
      nil
    end
  end
end
