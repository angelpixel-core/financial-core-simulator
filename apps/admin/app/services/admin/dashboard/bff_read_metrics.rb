module Admin
  module Dashboard
    class BffReadMetrics
      def initialize(
        metrics_source: Admin::DashboardMetrics.new,
        overview_serializer: Admin::Dashboard::OverviewResponseSerializer.new
      )
        @metrics_source = metrics_source
        @overview_serializer = overview_serializer
      end

      def call
        metrics = @metrics_source.call
        overview_payload = @overview_serializer.serialize(metrics: metrics)
        legacy_payload = overview_payload.fetch("legacy", {})

        normalized = legacy_payload.deep_symbolize_keys
        normalized[:latest_global] = metrics[:latest_global] if metrics[:latest_global].is_a?(Hash)
        normalized[:risk_view] = metrics[:risk_view]
        normalized
      end
    end
  end
end
