require_relative "routes/admin_routes"
require_relative "routes/dashboard_routes"
require_relative "routes/runs_routes"
require_relative "routes/legacy_routes"
require_relative "routes/system_routes"
require_relative "routes/development_routes"

Rails.application.routes.draw do
  mount Rswag::Ui::Engine => "/api-docs"
  mount Rswag::Api::Engine => "/api-docs"
  root to: "landing#index"
  get "/request-demo", to: "request_demos#new", as: :new_request_demo
  post "/request-demo", to: "request_demos#create", as: :request_demo
  get "/request-demo/success", to: "request_demos#success", as: :request_demo_success
  get "/demo-datasets/valid", to: "demo/datasets#valid", as: :demo_dataset_valid
  get "/demo-datasets/invalid", to: "demo/datasets#invalid", as: :demo_dataset_invalid

  extend AdminRoutes
  extend DashboardRoutes
  extend RunRoutes
  extend LegacyRoutes
  extend SystemRoutes

  extend DevelopmentRoutes if Rails.env.development? && defined?(Lookbook)

  mount Avo::Engine, at: Avo.configuration.root_path
end
