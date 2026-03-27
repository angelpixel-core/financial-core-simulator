# frozen_string_literal: true

module RouteConcerns
  module RunArtifactRedirects
    def self.extended(router)
      router.instance_exec do
        concern :run_artifact_redirects do
          get "result", to: redirect("/runs/%{id}/result")
          get "positions", to: redirect("/runs/%{id}/positions")
          get "pnl", to: redirect("/runs/%{id}/pnl")
          get "risk", to: redirect("/runs/%{id}/risk")
        end
      end
    end
  end
end
