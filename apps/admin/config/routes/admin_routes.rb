# frozen_string_literal: true

module AdminRoutes
  def self.extended(router)
    router.instance_exec do
      namespace :admin do
        get 'overview', to: 'overview#show', as: :overview
        get 'docs', to: 'docs#index', as: :docs
        get 'docs/:section', to: 'docs#show', as: :docs_section

        get 'overview/pnl-trend', to: 'overview#pnl_trend', as: :overview_pnl_trend
        get 'overview/runs-trend', to: 'overview#runs_trend', as: :overview_runs_trend
        get 'overview/status-mix', to: 'overview#status_mix', as: :overview_status_mix
        get 'overview/top-accounts', to: 'overview#top_accounts', as: :overview_top_accounts
        get 'overview/ingestion-validation-errors', to: 'overview#ingestion_validation_errors_panel',
                                                    as: :overview_ingestion_validation_errors
      end
    end
  end
end
