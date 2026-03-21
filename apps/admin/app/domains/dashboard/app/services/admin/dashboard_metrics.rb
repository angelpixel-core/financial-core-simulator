require "json"
require "bigdecimal"

module Admin
  class DashboardMetrics
    WINDOW_7_DAYS = 7.days
    WINDOW_30_DAYS = 30.days
    RECENT_RUNS_LIMIT = 50
    TREND_POINTS_LIMIT = 14
    PNL_TREND_SCAN_LIMIT = 100
    TOP_ACCOUNTS_LIMIT = 5
    INGESTION_ERRORS_LIMIT = 50
    VALIDATION_ERROR_CODES = [
      ::Runs::ErrorCodeMapper::VALIDATION_GENERAL,
      ::Runs::ErrorCodeMapper::VALIDATION_ACCOUNTING,
      ::Runs::ErrorCodeMapper::VALIDATION_RISK,
      ::Runs::ErrorCodeMapper::VALIDATION_COLLATERAL,
      ::Runs::ErrorCodeMapper::VALIDATION_TRADE_DECIMAL,
      ::Runs::ErrorCodeMapper::VALIDATION_UNKNOWN_REFERENCE,
      ::Runs::ErrorCodeMapper::VALIDATION_DUPLICATE_SEQ,
      ::Runs::ErrorCodeMapper::VALIDATION_INVALID_NUMBER
    ].freeze

    def initialize(ingestion_validation_error_mapper: Admin::Validation::IngestionValidationErrorMapper.new)
      @ingestion_validation_error_mapper = ingestion_validation_error_mapper
    end

    def call
      live_state = live_state_metrics
      total_runs_7d = runs_since(WINDOW_7_DAYS).count
      total_runs_30d = runs_since(WINDOW_30_DAYS).count
      success_rate = success_rate_last_50
      avg_duration = avg_duration_ms_last_50
      previous_total_runs_7d = runs_between(WINDOW_7_DAYS * 2, WINDOW_7_DAYS).count
      previous_total_runs_30d = runs_between(WINDOW_30_DAYS * 2, WINDOW_30_DAYS).count
      previous_success_rate = success_rate_for_scope(previous_recent_scope)
      previous_avg_duration = avg_duration_for_scope(previous_recent_scope)

      {
        total_runs_7d: total_runs_7d,
        total_runs_30d: total_runs_30d,
        success_rate_last_50: success_rate,
        avg_duration_ms_last_50: avg_duration,
        runs_trend_14d: runs_trend_14d,
        pnl_trend: pnl_trend,
        status_mix_30d: status_mix_30d,
        kpi_deltas: {
          total_runs_7d: delta_metadata(total_runs_7d, previous_total_runs_7d),
          total_runs_30d: delta_metadata(total_runs_30d, previous_total_runs_30d),
          success_rate_last_50: delta_metadata(success_rate, previous_success_rate),
          avg_duration_ms_last_50: delta_metadata(avg_duration, previous_avg_duration, inverse_good: true)
        },
        latest_run: latest_run_data,
        simulation_context: simulation_context_data,
        run_comparison: run_comparison_data,
        input_traceability: input_traceability_data,
        latest_global: latest_global_data(live_state),
        top_accounts: top_accounts_data(live_state)
      }
    end

    def ingestion_validation_errors(limit: INGESTION_ERRORS_LIMIT, source: nil, field: nil)
      entries = validation_failed_runs.map do |run|
        @ingestion_validation_error_mapper.map(run: run)
      end

      entries = filter_validation_errors_by_source(entries, source)
      entries = filter_validation_errors_by_field(entries, field)
      entries.first(limit)
    end

    private

    def validation_failed_runs
      Run.failed.where(error_code: VALIDATION_ERROR_CODES).order(id: :desc)
    end

    def filter_validation_errors_by_source(entries, source)
      return entries if source.blank?

      query = normalize_filter_query(source)
      entries.select { |entry| partial_source_match?(entry[:source], query) }
    end

    def filter_validation_errors_by_field(entries, field)
      return entries if field.blank?

      query = normalize_filter_query(field)
      entries.select { |entry| partial_match?(entry[:field], query) }
    end

    def partial_source_match?(value, query)
      expanded_source_aliases(value).any? { |candidate| candidate.include?(query) }
    end

    def expanded_source_aliases(value)
      normalized = normalize_filter_query(value)
      variants = [normalized]
      variants << normalized.gsub("source", "src") if normalized.include?("source")
      variants << normalized.gsub("src", "source") if normalized.include?("src")
      variants.uniq
    end

    def partial_match?(value, query)
      normalize_filter_query(value).include?(query)
    end

    def normalize_filter_query(value)
      value.to_s.downcase.strip
    end

    def runs_since(window)
      Run.where(created_at: window.ago..Time.current)
    end

    def runs_between(older_window, newer_window)
      Run.where(created_at: older_window.ago...newer_window.ago)
    end

    def recent_scope
      sample_scope(offset: 0)
    end

    def previous_recent_scope
      sample_scope(offset: RECENT_RUNS_LIMIT)
    end

    def sample_scope(offset:)
      sample_ids = Run.order(id: :desc).offset(offset).limit(RECENT_RUNS_LIMIT).pluck(:id)
      Run.where(id: sample_ids)
    end

    def success_rate_last_50
      success_rate_for_scope(recent_scope)
    end

    def avg_duration_ms_last_50
      avg_duration_for_scope(recent_scope)
    end

    def success_rate_for_scope(scope)
      total = scope.count
      return 0 if total.zero?

      ok = scope.where(status: Run.statuses.fetch("succeeded")).count
      ((ok.to_f / total) * 100).round(0)
    end

    def avg_duration_for_scope(scope)
      average = scope.where(status: Run.statuses.fetch("succeeded")).where.not(duration_ms: nil).average(:duration_ms)
      average&.to_f&.round(1)
    end

    def delta_metadata(current_value, previous_value, inverse_good: false)
      return {direction: "unknown", delta_abs: nil, delta_pct: nil} if previous_value.nil?
      return {direction: "unknown", delta_abs: nil, delta_pct: nil} if previous_value.to_f.zero?

      difference = current_value.to_f - previous_value.to_f
      {
        direction: normalized_direction(difference, inverse_good: inverse_good),
        delta_abs: difference.abs.round(1),
        delta_pct: ((difference / previous_value.to_f) * 100).abs.round(1)
      }
    end

    def normalized_direction(difference, inverse_good: false)
      return "flat" if difference.zero?

      raw_direction = if difference.positive?
        "up"
      else
        "down"
      end

      return raw_direction unless inverse_good

      (raw_direction == "up") ? "down" : "up"
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

    def simulation_context_data
      return nil if latest_run.nil?

      payload = canonical_result_payload_for(latest_run)
      {
        dataset: dataset_name_for(latest_run),
        accounts_count: accounts_count_for(latest_run, payload: payload),
        events_count: events_count_for(latest_run),
        markets: markets_for(latest_run, payload: payload),
        input_hash: latest_run.input_hash,
        deterministic: "YES"
      }
    end

    def run_comparison_data
      runs = Run.succeeded.order(id: :desc).limit(2).to_a
      return nil if runs.empty?

      current_run = runs[0]
      previous_run = runs[1]
      current_payload = canonical_result_payload_for(current_run)
      previous_payload = previous_run.nil? ? nil : canonical_result_payload_for(previous_run)

      total_delta = delta_from_payloads(previous_payload, current_payload, key: "totalPnLQuote")
      realized_delta = delta_from_payloads(previous_payload, current_payload, key: "realizedNetPnLQuote")
      unrealized_delta = delta_from_payloads(previous_payload, current_payload, key: "unrealizedPnLQuote")

      {
        current_run_id: current_run.id,
        previous_run_id: previous_run&.id,
        total_pnl_delta: total_delta,
        realized_delta: realized_delta,
        unrealized_delta: unrealized_delta,
        deterministic_result: deterministic_result_label(
          current_run: current_run,
          previous_run: previous_run,
          total_delta: total_delta,
          realized_delta: realized_delta,
          unrealized_delta: unrealized_delta
        )
      }
    end

    def input_traceability_data
      return nil if latest_run.nil?

      {
        dataset: dataset_name_for(latest_run),
        input_hash: latest_run.input_hash,
        artifacts: {
          result_json_path: relative_to_project_root(latest_run.result_json_path),
          positions_csv_path: relative_to_project_root(latest_run.positions_csv_path),
          pnl_csv_path: relative_to_project_root(latest_run.pnl_csv_path)
        }
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
    rescue
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
      counts = runs_since(TREND_POINTS_LIMIT.days).group("DATE(created_at)").count

      (start_date..Date.current).map do |day|
        count = counts[day] || counts[day.to_s] || 0
        {day: day.strftime("%m-%d"), count: count}
      end
    end

    def pnl_trend
      points = Run.succeeded.order(created_at: :desc).limit(PNL_TREND_SCAN_LIMIT).filter_map do |run|
        pnl_trend_point(run)
      end

      points.first(TREND_POINTS_LIMIT).sort_by { |point| point[:timestamp] }
    end

    def pnl_trend_point(run)
      payload = canonical_result_payload_for(run)
      return nil if payload.nil?

      total = parse_decimal_or_nil(payload.dig("global", "totalPnLQuote"))
      return nil if total.nil?

      timestamp = run.valuation_timestamp || run.created_at
      return nil if timestamp.nil?

      {
        label: timestamp.utc.strftime("%m-%d %H:%M UTC"),
        timestamp: timestamp.utc.iso8601,
        total_pnl_quote: total.to_s("F")
      }
    end

    def canonical_result_payload_for(run)
      path = run.result_json_path
      return nil if path.blank?
      return nil unless File.exist?(path)

      JSON.parse(File.read(path))
    rescue JSON::ParserError
      nil
    end

    def dataset_name_for(run)
      input_json = run.input_json.is_a?(Hash) ? run.input_json : {}
      input_json["dataset"] || input_json["datasetName"] || "N/A"
    end

    def events_count_for(run)
      input_json = run.input_json.is_a?(Hash) ? run.input_json : {}
      events = input_json["events"]
      trades = input_json["trades"]
      orders = input_json["orders"]

      return events.length if events.is_a?(Array)
      return trades.length if trades.is_a?(Array)
      return orders.length if orders.is_a?(Array)

      nil
    end

    def accounts_count_for(run, payload:)
      input_json = run.input_json.is_a?(Hash) ? run.input_json : {}
      input_accounts = input_json["accounts"]
      return input_accounts.length if input_accounts.is_a?(Array)

      payload_accounts = payload&.fetch("accounts", nil)
      return payload_accounts.length if payload_accounts.is_a?(Array)

      nil
    end

    def markets_for(run, payload:)
      input_json = run.input_json.is_a?(Hash) ? run.input_json : {}

      input_markets = input_json["markets"]
      if input_markets.is_a?(Array)
        normalized = input_markets.filter_map { |entry| entry.to_s.strip.presence }.uniq
        return normalized.join(", ") if normalized.any?
      end

      events = input_json["events"]
      if events.is_a?(Array)
        from_events = events.filter_map { |entry| entry.is_a?(Hash) ? entry["marketId"].to_s.strip.presence : nil }.uniq
        return from_events.join(", ") if from_events.any?
      end

      payload_accounts = payload&.fetch("accounts", nil)
      if payload_accounts.is_a?(Array)
        from_payload = payload_accounts.filter_map do |entry|
          next unless entry.is_a?(Hash)

          risk_events = entry["riskEvents"]
          next unless risk_events.is_a?(Array)

          risk_events.filter_map { |risk_event|
            risk_event.is_a?(Hash) ? risk_event["marketId"].to_s.strip.presence : nil
          }
        end.flatten.uniq
        return from_payload.join(", ") if from_payload.any?
      end

      nil
    end

    def delta_from_payloads(previous_payload, current_payload, key:)
      return nil if previous_payload.nil? || current_payload.nil?

      previous_value = parse_decimal_or_nil(previous_payload.dig("global", key))
      current_value = parse_decimal_or_nil(current_payload.dig("global", key))
      return nil if previous_value.nil? || current_value.nil?

      (current_value - previous_value).to_s("F")
    end

    def deterministic_result_label(current_run:, previous_run:, total_delta:, realized_delta:, unrealized_delta:)
      return "Comparison unavailable (need at least two succeeded runs)." if previous_run.nil?
      return "Comparison unavailable (missing canonical artifacts)." if [total_delta, realized_delta,
        unrealized_delta].all?(&:nil?)

      same_input = current_run.input_hash.present? &&
        previous_run.input_hash.present? &&
        current_run.input_hash == previous_run.input_hash
      deltas_zero = [total_delta, realized_delta, unrealized_delta].compact.all? { |value| BigDecimal(value).zero? }

      return "Identical output for matching input hash." if same_input && deltas_zero

      "Differences detected between latest runs."
    end

    def relative_to_project_root(path)
      path_string = path.to_s
      return nil if path_string.blank?

      pathname = Pathname(path_string)
      return path_string unless pathname.absolute?

      pathname.relative_path_from(Rails.root).to_s
    rescue ArgumentError
      path_string
    end

    def parse_decimal_or_nil(value)
      return nil if value.nil?

      BigDecimal(value.to_s)
    rescue ArgumentError
      nil
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
      BigDecimal(0)
    end
  end
end
