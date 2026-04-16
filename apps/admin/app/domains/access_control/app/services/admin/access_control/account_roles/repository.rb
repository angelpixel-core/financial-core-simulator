# frozen_string_literal: true

module Admin
  module AccessControl
    module AccountRoles
      class Repository
        def initialize(roles_repository: Admin::AccessControl::Roles::Repository.new)
          @roles_repository = roles_repository
        end

        def assign_role!(account_id:, role_key:, assigned_by_id: nil, context: {})
          role = AccessControlRole.find_by!(key: role_key.to_s)

          AccessControlAccountRole.find_or_create_by!(
            account_id: account_id,
            access_control_role_id: role.id
          ) do |assignment|
            assignment.assigned_by_id = assigned_by_id
            assignment.assigned_context = context
          end
        end

        def role_for_account(account)
          return nil if account.nil?

          role = AccessControlRole
            .joins(:access_control_account_roles)
            .where(access_control_account_roles: {account_id: account.id})
            .order(level: :desc)
            .first

          role&.key
        end

        def role_allowed?(actual_role:, required_role:)
          @roles_repository.level_for(actual_role) >= @roles_repository.level_for(required_role)
        end
      end
    end
  end
end
