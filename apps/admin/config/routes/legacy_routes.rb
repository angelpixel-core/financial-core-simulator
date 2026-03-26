# frozen_string_literal: true

module LegacyRoutes
  def self.extended(router)
    router.instance_exec do
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
    end
  end
end
