# frozen_string_literal: true

module Runs
  module ArtifactRoutes
    def self.extended(router)
      router.instance_exec do
        scope ":id" do
          get "result", to: "run_artifacts#result", as: :run_result
          get "positions", to: "run_artifacts#positions", as: :run_positions
          get "pnl", to: "run_artifacts#pnl", as: :run_pnl
          get "risk", to: "run_artifacts#risk", as: :run_risk
          post "execute", to: "run_executions#create", as: :run_execute
          post "verify", to: "run_verifications#create", as: :run_verify
        end
      end
    end
  end
end
