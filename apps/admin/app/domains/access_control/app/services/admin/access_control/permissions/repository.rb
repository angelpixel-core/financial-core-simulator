# frozen_string_literal: true

module Admin
  module AccessControl
    module Permissions
      class Repository
        def grant!(role_key:, resource:, action:)
          role = AccessControlRole.find_by!(key: role_key.to_s)

          AccessControlPermission.find_or_create_by!(
            access_control_role_id: role.id,
            resource: resource.to_s,
            action: action.to_s
          )
        end

        def allowed?(role_key:, resource:, action:)
          role = AccessControlRole.find_by(key: role_key.to_s)
          return false unless role

          AccessControlPermission.exists?(
            access_control_role_id: role.id,
            resource: resource.to_s,
            action: action.to_s
          )
        end
      end
    end
  end
end
