module Admin
  module Dashboard
    class OverviewResponseSerializer
      def initialize(compatibility_guard: Admin::Dashboard::CompatibilityGuard.new)
        @compatibility_guard = compatibility_guard
      end

      def serialize(metrics:)
        payload = {
          "runKpis" => {
            "totalRuns7d" => metrics[:total_runs_7d],
            "totalRuns30d" => metrics[:total_runs_30d],
            "successRateLast50" => metrics[:success_rate_last_50],
            "avgDurationMsLast50" => metrics[:avg_duration_ms_last_50]
          },
          "runsTrend14d" => metrics[:runs_trend_14d],
          "statusMix30d" => metrics[:status_mix_30d],
          "latestRun" => metrics[:latest_run],
          "globalSummary" => metrics[:latest_global],
          "topAccounts" => metrics[:top_accounts]
        }

        @compatibility_guard.overview_payload(payload: payload, metrics: metrics)
      end
    end
  end
end
