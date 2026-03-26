# frozen_string_literal: true

module AdminRoutes
  def self.extended(router)
    router.instance_exec do
      get '/admin/overview', to: 'admin/overview#show', as: :admin_overview
      get '/admin/docs', to: 'admin/docs#index', as: :admin_docs
      get '/admin/docs/:section', to: 'admin/docs#show', as: :admin_docs_section

      get '/admin/overview/pnl-trend', to: 'admin/overview#pnl_trend', as: :admin_overview_pnl_trend
      get '/admin/overview/runs-trend', to: 'admin/overview#runs_trend', as: :admin_overview_runs_trend
      get '/admin/overview/status-mix', to: 'admin/overview#status_mix', as: :admin_overview_status_mix
      get '/admin/overview/top-accounts', to: 'admin/overview#top_accounts', as: :admin_overview_top_accounts
      get '/admin/overview/ingestion-validation-errors', to: 'admin/overview#ingestion_validation_errors_panel',
                                                         as: :admin_overview_ingestion_validation_errors
    end
  end
end
