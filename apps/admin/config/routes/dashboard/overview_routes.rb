# frozen_string_literal: true

module Dashboard
  module OverviewRoutes
    def self.extended(router)
      router.instance_exec do
        get "overview", to: "overview#dashboard_overview", as: :dashboard_overview
        get "financial-overview/:run_id",
          to: "overview#dashboard_financial_overview",
          as: :dashboard_financial_overview
        get "top-accounts", to: "overview#dashboard_top_accounts", as: :dashboard_top_accounts
        get "risk", to: "overview#dashboard_risk", as: :dashboard_risk
        get "trend", to: "overview#dashboard_trend", as: :dashboard_trend
        get "latest-run", to: "overview#dashboard_latest_run", as: :dashboard_latest_run
        get "ingestion-validation-errors",
          to: "overview#ingestion_validation_errors",
          as: :dashboard_ingestion_validation_errors
      end
    end
  end
end
