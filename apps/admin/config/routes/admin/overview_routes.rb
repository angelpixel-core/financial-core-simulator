# frozen_string_literal: true

module Admin
  module OverviewRoutes
    def self.extended(router)
      router.instance_exec do
        scope :overview do
          get "/", to: "overview#show", as: :overview
          get "runs-trend", to: "overview#runs_trend", as: :overview_runs_trend
          get "status-mix", to: "overview#status_mix", as: :overview_status_mix
          get "top-accounts",
            to: "overview#top_accounts",
            as: :overview_top_accounts
          get "exports/:card_type",
            to: "overview#export_financial_overview",
            as: :overview_export
          get "ingestion-validation-errors",
            to: "overview#ingestion_validation_errors_panel",
            as: :overview_ingestion_validation_errors
        end
      end
    end
  end
end
