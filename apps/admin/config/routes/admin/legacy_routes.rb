# frozen_string_literal: true

module Admin
  module LegacyRoutes
    def self.extended(router)
      router.instance_exec do
        scope :admin do
          scope :resources do
            scope 'runs/:id' do
              concerns :run_artifact_redirects
            end
          end
        end
      end
    end
  end
end
