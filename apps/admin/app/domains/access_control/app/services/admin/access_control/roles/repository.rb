# frozen_string_literal: true

module Admin
  module AccessControl
    module Roles
      class Repository
        DEFAULT_LEVEL_BY_ROLE = {
          "viewer" => 0,
          "operator" => 1,
          "admin" => 2
        }.freeze

        def ensure_defaults!
          DEFAULT_LEVEL_BY_ROLE.each do |key, level|
            AccessControlRole.find_or_create_by!(key: key) { |role| role.level = level }
          end
        end

        def find_by_key(role_key)
          AccessControlRole.find_by(key: role_key.to_s)
        end

        def level_for(role_key)
          role = find_by_key(role_key)
          return role.level if role

          DEFAULT_LEVEL_BY_ROLE.fetch(role_key.to_s, DEFAULT_LEVEL_BY_ROLE.fetch("viewer"))
        end
      end
    end
  end
end
