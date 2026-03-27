# frozen_string_literal: true

require_relative "concerns/run_artifact_redirects"

module LegacyRoutes
  def self.extended(router)
    router.instance_exec do
      extend RouteConcerns::RunArtifactRedirects

      extend Admin::LegacyRoutes
      extend Avo::LegacyRoutes
    end
  end
end
