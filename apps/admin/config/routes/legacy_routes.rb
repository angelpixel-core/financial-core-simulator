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

      scope :avo do
        scope :resources do
          scope 'runs/:id' do
            concerns :run_artifact_redirects
          end
        end
      end

      scope :avo do
        get '/', to: redirect('/admin'), as: :legacy_avo_root
        get '/*path', to: redirect('/admin/%{path}'), as: :legacy_avo_catch_all
      end
    end
  end
end
