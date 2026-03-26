# frozen_string_literal: true

module RunRoutes
  def self.extended(router)
    router.instance_exec do
      get "/runs/latest/result", to: "run_artifacts#latest", as: :run_latest_result
      get "/runs/latest/positions", to: "run_artifacts#latest_positions", as: :run_latest_positions
      get "/runs/latest/pnl", to: "run_artifacts#latest_pnl", as: :run_latest_pnl
      get "/runs/latest/risk", to: "run_artifacts#latest_risk", as: :run_latest_risk

      get "/runs/:id/result", to: "run_artifacts#result", as: :run_result
      get "/runs/:id/positions", to: "run_artifacts#positions", as: :run_positions
      get "/runs/:id/pnl", to: "run_artifacts#pnl", as: :run_pnl
      get "/runs/:id/risk", to: "run_artifacts#risk", as: :run_risk
      post "/runs/:id/execute", to: "run_executions#create", as: :run_execute
      post "/runs/:id/verify", to: "run_verifications#create", as: :run_verify
    end
  end
end
