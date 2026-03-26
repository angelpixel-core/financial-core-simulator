# frozen_string_literal: true

module DashboardRoutes
  def self.extended(router)
    router.instance_exec do
      get "/dashboard/overview", to: "admin/overview#dashboard_overview", as: :dashboard_overview
      get "/dashboard/top-accounts", to: "admin/overview#dashboard_top_accounts", as: :dashboard_top_accounts
      get "/dashboard/risk", to: "admin/overview#dashboard_risk", as: :dashboard_risk
      get "/dashboard/trend", to: "admin/overview#dashboard_trend", as: :dashboard_trend
      get "/dashboard/latest-run", to: "admin/overview#dashboard_latest_run", as: :dashboard_latest_run
      get "/dashboard/ingestion-validation-errors",
        to: "admin/overview#ingestion_validation_errors",
        as: :dashboard_ingestion_validation_errors
    end
  end
end
