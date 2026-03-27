# frozen_string_literal: true

require_relative "dashboard/overview_routes"

module DashboardRoutes
  def self.extended(router)
    router.instance_exec do
      scope :dashboard, module: :admin do
        extend Dashboard::OverviewRoutes
      end
    end
  end
end
