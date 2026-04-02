# frozen_string_literal: true

module Admin
  module SystemHealthRoutes
    def self.extended(router)
      router.instance_exec do
        get "system-health", to: "system_health#show", as: :system_health
        get "system-health/pnl-trend", to: "system_health#pnl_trend", as: :system_health_pnl_trend
      end
    end
  end
end
