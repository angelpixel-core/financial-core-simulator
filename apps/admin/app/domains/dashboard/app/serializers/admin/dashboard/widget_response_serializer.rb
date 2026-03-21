module Admin
  module Dashboard
    class WidgetResponseSerializer
      def initialize(compatibility_guard: Admin::Dashboard::CompatibilityGuard.new)
        @compatibility_guard = compatibility_guard
      end

      def top_accounts(metrics:)
        serialize_widget(payload: {"topAccounts" => metrics[:top_accounts] || []},
          required_widget_keys: ["topAccounts"])
      end

      def risk(metrics:)
        serialize_widget(payload: {"riskView" => metrics[:risk_view] || {}}, required_widget_keys: ["riskView"])
      end

      def trend(metrics:)
        serialize_widget(payload: {"runsTrend14d" => metrics[:runs_trend_14d] || []},
          required_widget_keys: ["runsTrend14d"])
      end

      def latest_run(metrics:)
        serialize_widget(payload: {"latestRun" => metrics[:latest_run] || {}}, required_widget_keys: ["latestRun"])
      end

      private

      def serialize_widget(payload:, required_widget_keys:)
        @compatibility_guard.widget_payload(payload: payload, required_widget_keys: required_widget_keys)
      end
    end
  end
end
