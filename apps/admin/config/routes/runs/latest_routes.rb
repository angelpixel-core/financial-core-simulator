# frozen_string_literal: true

module Runs
  module LatestRoutes
    def self.extended(router)
      router.instance_exec do
        scope :latest do
          get 'result', to: 'run_artifacts#latest', as: :run_latest_result
          get 'positions', to: 'run_artifacts#latest_positions', as: :run_latest_positions
          get 'pnl', to: 'run_artifacts#latest_pnl', as: :run_latest_pnl
          get 'risk', to: 'run_artifacts#latest_risk', as: :run_latest_risk
        end
      end
    end
  end
end
