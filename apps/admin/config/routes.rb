Rails.application.routes.draw do
  root to: "landing#index"

  get "/admin/overview", to: "admin/overview#show", as: :admin_overview
  get "/admin/overview/runs-trend", to: "admin/overview#runs_trend", as: :admin_overview_runs_trend
  get "/admin/overview/status-mix", to: "admin/overview#status_mix", as: :admin_overview_status_mix
  get "/admin/overview/top-accounts", to: "admin/overview#top_accounts", as: :admin_overview_top_accounts
  get "/admin/overview/ingestion-validation-errors", to: "admin/overview#ingestion_validation_errors_panel", 
as: :admin_overview_ingestion_validation_errors
  get "/dashboard/overview", to: "admin/overview#dashboard_overview", as: :dashboard_overview
  get "/dashboard/top-accounts", to: "admin/overview#dashboard_top_accounts", as: :dashboard_top_accounts
  get "/dashboard/risk", to: "admin/overview#dashboard_risk", as: :dashboard_risk
  get "/dashboard/trend", to: "admin/overview#dashboard_trend", as: :dashboard_trend
  get "/dashboard/latest-run", to: "admin/overview#dashboard_latest_run", as: :dashboard_latest_run
  get "/dashboard/ingestion-validation-errors", to: "admin/overview#ingestion_validation_errors", 
as: :dashboard_ingestion_validation_errors
  get "/admin/resources/runs/:id/result", to: redirect("/runs/%{id}/result")
  get "/admin/resources/runs/:id/positions", to: redirect("/runs/%{id}/positions")
  get "/admin/resources/runs/:id/pnl", to: redirect("/runs/%{id}/pnl")
  get "/admin/resources/runs/:id/risk", to: redirect("/runs/%{id}/risk")

  get "/avo/resources/runs/:id/result", to: redirect("/runs/%{id}/result")
  get "/avo/resources/runs/:id/positions", to: redirect("/runs/%{id}/positions")
  get "/avo/resources/runs/:id/pnl", to: redirect("/runs/%{id}/pnl")
  get "/avo/resources/runs/:id/risk", to: redirect("/runs/%{id}/risk")
  get "/avo", to: redirect("/admin"), as: :legacy_avo_root
  get "/avo/*path", to: redirect("/admin/%{path}"), as: :legacy_avo_catch_all

  if Rails.env.development? && defined?(Lookbook)
    mount Lookbook::Engine, at: "/lookbook"
  end

  mount Avo::Engine, at: Avo.configuration.root_path
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"

  get "/runs/:id/result", to: "run_artifacts#result", as: :run_result
  get "/runs/:id/positions", to: "run_artifacts#positions", as: :run_positions
  get "/runs/:id/pnl", to: "run_artifacts#pnl", as: :run_pnl
  get "/runs/:id/risk", to: "run_artifacts#risk", as: :run_risk
  post "/runs/:id/execute", to: "run_executions#create", as: :run_execute
  post "/runs/:id/verify", to: "run_verifications#create", as: :run_verify
end
