# frozen_string_literal: true

module FCS
  module Projector
    # Builds the default projection store for read models.
    #
    # @example
    #   store = FCS::Projector::DefaultProjectionStoreFactory.new(today: Date.today).call
    class DefaultProjectionStoreFactory
      # @param today [Date]
      def initialize(today:)
        @today = today
      end

      # @return [FCS::Projector::ProjectionStore]
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
