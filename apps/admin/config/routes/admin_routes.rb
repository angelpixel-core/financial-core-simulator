# frozen_string_literal: true

require_relative "admin/overview_routes"
require_relative "admin/system_health_routes"
require_relative "admin/fx_routes"
require_relative "admin/demo_datasets_routes"
require_relative "admin/legacy_routes"
require_relative "avo/legacy_routes"

module AdminRoutes
  def self.extended(router)
    router.instance_exec do
      namespace :admin do
        extend Admin::OverviewRoutes
        extend Admin::SystemHealthRoutes
        extend Admin::DemoDatasetsRoutes
        extend Admin::FxRoutes
      end
    end
  end
end
