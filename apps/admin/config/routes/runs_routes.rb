# frozen_string_literal: true

require_relative "runs/latest_routes"
require_relative "runs/artifact_routes"

module RunRoutes
  def self.extended(router)
    router.instance_exec do
      scope :runs do
        extend Runs::LatestRoutes
        extend Runs::ArtifactRoutes
      end
    end
  end
end
