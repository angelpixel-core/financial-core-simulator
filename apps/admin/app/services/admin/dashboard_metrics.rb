require "json"
require "bigdecimal"

module Admin
  class DashboardMetrics
    WINDOW_7_DAYS = 7.days
    WINDOW_30_DAYS = 30.days
    RECENT_RUNS_LIMIT = 50
    TOP_ACCOUNTS_LIMIT = 5

    def call
      live_state = live_state_metrics

      {
        total_runs_7d: runs_since(WINDOW_7_DAYS).count,
        total_runs_30d: runs_since(WINDOW_30_DAYS).count,
        success_rate_last_50: success_rate_last_50,
        avg_duration_ms_last_50: avg_duration_ms_last_50,
        runs_trend_14d: runs_trend_14d,
        status_mix_30d: status_mix_30d,
        latest_run: latest_run_data,
        latest_global: latest_global_data(live_state),
        top_accounts: top_accounts_data(live_state)
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

    def latest_global_data(live_state)
      live_global = live_state&.fetch(:latest_global, nil)
      return live_global if live_global.is_a?(Hash)

      payload = latest_payload
      return nil if payload.nil?

      payload["global"]
    end

    def top_accounts_data(live_state)
      live_accounts = live_state&.fetch(:top_accounts, nil)
      return live_accounts if live_accounts.is_a?(Array)

      payload = latest_payload
      return [] if payload.nil?

      accounts = payload.fetch("accounts", [])
      accounts
        .map { |account| account_metrics(account) }
        .sort_by { |entry| -entry[:total_pnl_quote] }
        .first(TOP_ACCOUNTS_LIMIT)
    end

    def live_state_metrics
      Admin::LiveStateMetrics.new.call
    rescue StandardError
      nil
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

    def runs_trend_14d
      start_date = 13.days.ago.to_date
      counts = runs_since(14.days).group("DATE(created_at)").count

      (start_date..Date.current).map do |day|
        count = counts[day] || counts[day.to_s] || 0
        { day: day.strftime("%m-%d"), count: count }
      end
    end

    def status_mix_30d
      raw = runs_since(WINDOW_30_DAYS).group(:status).count
      {
        queued: raw.fetch("queued", 0) + raw.fetch(0, 0),
        running: raw.fetch("running", 0) + raw.fetch(1, 0),
        succeeded: raw.fetch("succeeded", 0) + raw.fetch(2, 0),
        failed: raw.fetch("failed", 0) + raw.fetch(3, 0)
      }
    end

    def decimal_value(value)
      BigDecimal(value.to_s)
    rescue ArgumentError
      BigDecimal("0")
    end
  end
end
