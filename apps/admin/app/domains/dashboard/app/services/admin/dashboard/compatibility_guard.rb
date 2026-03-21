module Admin
  module Dashboard
    class CompatibilityGuard
      CONTRACT_VERSION = "v1"

      OVERVIEW_REQUIRED_KEYS = %w[
        contractVersion
        runKpis
        runsTrend14d
        statusMix30d
        latestRun
        globalSummary
        topAccounts
        legacy
      ].freeze

      LEGACY_OVERVIEW_REQUIRED_KEYS = %w[
        total_runs_7d
        total_runs_30d
        success_rate_last_50
        avg_duration_ms_last_50
        runs_trend_14d
        status_mix_30d
        latest_run
        latest_global
        top_accounts
      ].freeze

      def overview_payload(payload:, metrics:)
        compatible_payload = normalize_hash(payload).merge(
          "contractVersion" => CONTRACT_VERSION,
          "legacy" => legacy_overview_payload(metrics)
        )

        validate_required_keys!(compatible_payload, OVERVIEW_REQUIRED_KEYS, field: "overview")
        validate_required_keys!(compatible_payload.fetch("legacy"), LEGACY_OVERVIEW_REQUIRED_KEYS,
          field: "overview.legacy")

        compatible_payload
      end

      def widget_payload(payload:, required_widget_keys:)
        compatible_payload = normalize_hash(payload).merge("contractVersion" => CONTRACT_VERSION)
        required_keys = Array(required_widget_keys) + ["contractVersion"]
        validate_required_keys!(compatible_payload, required_keys, field: "widget")
        compatible_payload
      end

      private

      def legacy_overview_payload(metrics)
        {
          "total_runs_7d" => metrics[:total_runs_7d],
          "total_runs_30d" => metrics[:total_runs_30d],
          "success_rate_last_50" => metrics[:success_rate_last_50],
          "avg_duration_ms_last_50" => metrics[:avg_duration_ms_last_50],
          "runs_trend_14d" => metrics[:runs_trend_14d],
          "status_mix_30d" => metrics[:status_mix_30d],
          "latest_run" => metrics[:latest_run],
          "latest_global" => metrics[:latest_global],
          "top_accounts" => metrics[:top_accounts]
        }.deep_stringify_keys
      end

      def normalize_hash(payload)
        return {} if payload.nil?
        return payload.deep_stringify_keys if payload.respond_to?(:deep_stringify_keys)

        payload
      end

      def validate_required_keys!(payload, required_keys, field:)
        missing = required_keys.reject { |key| payload.key?(key) }
        return if missing.empty?

        raise ArgumentError, "Missing required compatibility keys for #{field}: #{missing.join(', ')}"
      end
    end
  end
end
