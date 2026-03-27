# frozen_string_literal: true

module LegacyRoutes
  def self.extended(router)
    router.instance_exec do
      concern :run_artifact_redirects do
        get 'result', to: redirect('/runs/%{id}/result')
        get 'positions', to: redirect('/runs/%{id}/positions')
        get 'pnl', to: redirect('/runs/%{id}/pnl')
        get 'risk', to: redirect('/runs/%{id}/risk')
      end

      extend Admin::LegacyResourceRoutes
      extend Avo::LegacyResourceRoutes
      extend Avo::LegacyRoutes
    end
  end
end
