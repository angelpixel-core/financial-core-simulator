# frozen_string_literal: true

module FCS
  module Projector
    # Builds the default projection store for read models.
    class DefaultProjectionStoreFactory
      def initialize(today:)
        @today = today
      end

      def call
        FCS::Projector::ProjectionStore.new(
          projections: {
            "overview" => FCS::Projector::OverviewKpiStatusMixProjector.new,
            "trend" => FCS::Projector::TrendLatestRunProjector.new(today: @today),
            "topAccountsRisk" => FCS::Projector::TopAccountsRiskProjector.new
          }
        )
      end
    end
  end
end
