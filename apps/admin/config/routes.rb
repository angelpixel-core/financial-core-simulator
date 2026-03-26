require_relative 'routes/admin_routes'
require_relative 'routes/dashboard_routes'
require_relative 'routes/run_routes'
require_relative 'routes/legacy_routes'
require_relative 'routes/system_routes'
require_relative 'routes/development_routes'

Rails.application.routes.draw do
  root to: 'landing#index'

  extend AdminRoutes
  extend DashboardRoutes
  extend RunRoutes
  extend LegacyRoutes
  extend SystemRoutes

  extend DevelopmentRoutes if Rails.env.development? && defined?(Lookbook)

  mount Avo::Engine, at: Avo.configuration.root_path
end
