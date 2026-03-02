Rails.application.routes.draw do
  get "/admin/overview", to: "admin/overview#show", as: :admin_overview

  get "/avo/resources/runs/:id/result", to: redirect("/runs/%{id}/result")
  get "/avo/resources/runs/:id/positions", to: redirect("/runs/%{id}/positions")
  get "/avo/resources/runs/:id/pnl", to: redirect("/runs/%{id}/pnl")

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
end
