# frozen_string_literal: true

module Admin
  module SystemHealthRoutes
    def self.extended(router)
      router.instance_exec do
        get 'system-health', to: 'system_health#show', as: :system_health
      end
    end
  end
end
