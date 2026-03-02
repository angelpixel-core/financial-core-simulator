require "json"
require "bigdecimal"

module Admin
  class DashboardMetrics
    WINDOW_7_DAYS = 7.days
    WINDOW_30_DAYS = 30.days
    RECENT_RUNS_LIMIT = 50
    TOP_ACCOUNTS_LIMIT = 5

    def call
      {
        total_runs_7d: runs_since(WINDOW_7_DAYS).count,
        total_runs_30d: runs_since(WINDOW_30_DAYS).count,
        success_rate_last_50: success_rate_last_50,
        avg_duration_ms_last_50: avg_duration_ms_last_50,
        latest_run: latest_run_data,
        latest_global: latest_global_data,
        top_accounts: top_accounts_data
      }
    end

    private

    def runs_since(window)
      Run.where(created_at: window.ago..Time.current)
    end

    def recent_scope
      Run.order(id: :desc).limit(RECENT_RUNS_LIMIT)
    end

    def success_rate_last_50
      total = recent_scope.count
      return 0 if total.zero?

      ok = recent_scope.where(status: Run.statuses.fetch("succeeded")).count
      ((ok.to_f / total) * 100).round(0)
    end

    def avg_duration_ms_last_50
      average = recent_scope.where(status: Run.statuses.fetch("succeeded")).where.not(duration_ms: nil).average(:duration_ms)
      average&.to_f&.round(1)
    end

    def latest_run
      @latest_run ||= Run.succeeded.order(id: :desc).first
    end

    def latest_run_data
      return nil if latest_run.nil?

      {
        id: latest_run.id,
        input_hash: latest_run.input_hash,
        duration_ms: latest_run.duration_ms,
        schema_version: latest_run.schema_version,
        engine_version: latest_run.engine_version
      }
    end

    def latest_payload
      return nil if latest_run.nil?
      return nil if latest_run.result_json_path.blank?
      return nil unless File.exist?(latest_run.result_json_path)

      JSON.parse(File.read(latest_run.result_json_path))
    rescue JSON::ParserError
      nil
    end

    def latest_global_data
      payload = latest_payload
      return nil if payload.nil?

      payload["global"]
    end

    def top_accounts_data
      payload = latest_payload
      return [] if payload.nil?

      accounts = payload.fetch("accounts", [])
      accounts
        .map { |account| account_metrics(account) }
        .sort_by { |entry| -entry[:total_pnl_quote] }
        .first(TOP_ACCOUNTS_LIMIT)
    end

    def account_metrics(account)
      totals = account.fetch("totals", {})
      {
        account_id: account["accountId"],
        total_pnl_quote: decimal_value(totals["totalPnLQuote"]),
        realized_net_pnl_quote: decimal_value(totals["realizedNetPnLQuote"]),
        unrealized_pnl_quote: decimal_value(totals["unrealizedPnLQuote"])
      }
    end

    def decimal_value(value)
      BigDecimal(value.to_s)
    rescue ArgumentError
      BigDecimal("0")
    end
  end
end
