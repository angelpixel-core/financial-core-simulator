require "json"
require "csv"
require "bigdecimal"
require "time"

module Admin
  module Dashboard
    class SeedMetrics
      SUCCESS_STATUS = "success"
      FAILED_STATUS = "failed"
      VALIDATION_STATUS = "validation_error"
      TRADE_WINDOWS = {
        "30d" => 30,
        "60d" => 60,
        "90d" => 90,
        "all-time" => nil
      }.freeze

      def initialize(seed_dir: Rails.root.join("storage", "runs", "dashboard_seed"))
        @seed_dir = seed_dir
      end

      def call(trades_window: "all-time")
        runs = load_runs
        pnl_points = load_pnl_points
        positions = load_positions
        selected_trades_window = normalize_trades_window(trades_window)

        {
          total_runs_7d: runs_in_window(runs, days: 7).length,
          total_runs_30d: runs_in_window(runs, days: 30).length,
          total_trades: successful_trades(runs, selected_trades_window),
          total_trades_window: selected_trades_window,
          success_rate_last_50: success_rate_last_50(runs),
          avg_duration_ms_last_50: avg_duration_ms_last_50(runs),
          runs_trend_14d: runs_trend_14d(runs),
          pnl_trend: pnl_trend(pnl_points),
          status_mix_30d: status_mix_30d(runs),
          kpi_deltas: kpi_deltas(runs),
          latest_run: latest_run_data(runs),
          simulation_context: simulation_context_data(runs, positions),
          run_comparison: run_comparison_data(runs),
          input_traceability: input_traceability_data(runs),
          latest_global: latest_global_data(pnl_points),
          top_accounts: top_accounts_data(positions, pnl_points)
        }
      end

      def ingestion_validation_errors(limit: 50, source: nil, field: nil)
        entries = load_runs
          .select { |run| run.fetch("status") == VALIDATION_STATUS }
          .map { |run| validation_error_entry(run) }

        entries = filter_by_source(entries, source)
        entries = filter_by_field(entries, field)
        entries.first(limit)
      end

      private

      def load_runs
        path = File.join(@seed_dir, "runs.json")
        return [] unless File.exist?(path)

        JSON.parse(File.read(path))
      rescue JSON::ParserError
        []
      end

      def load_pnl_points
        path = File.join(@seed_dir, "pnl.csv")
        return [] unless File.exist?(path)

        CSV.read(path, headers: true).map do |row|
          date = Date.parse(row["date"])
          {
            date: date,
            total: row["total_pnl"].to_f,
            realized: row["realized_pnl"].to_f,
            unrealized: row["unrealized_pnl"].to_f,
            runs: row["runs"].to_i,
            success_runs: row["success_runs"].to_i
          }
        end
      rescue ArgumentError
        []
      end

      def load_positions
        path = File.join(@seed_dir, "positions.csv")
        return [] unless File.exist?(path)

        CSV.read(path, headers: true).map do |row|
          {
            account_id: row["account_id"],
            market_id: row["market_id"],
            quantity: row["quantity"].to_f,
            avg_cost: row["avg_cost"].to_f
          }
        end
      rescue ArgumentError
        []
      end

      def runs_in_window(runs, days:)
        cutoff = Time.now.utc - (days * 86_400)
        runs.select { |run| parse_time(run["created_at"]) >= cutoff }
      end

      def successful_trades(runs, window_key)
        days = TRADE_WINDOWS.fetch(window_key)
        scoped_runs = days.nil? ? runs : runs_in_window(runs, days: days)
        scoped_runs.sum { |run| run.fetch("trade_count", 0).to_i }
      end

      def normalize_trades_window(value)
        normalized = value.to_s.strip.downcase
        return normalized if TRADE_WINDOWS.key?(normalized)

        "all-time"
      end

      def success_rate_last_50(runs)
        sample = recent_runs(runs, limit: 50)
        return 0 if sample.empty?

        success_count = sample.count { |run| run.fetch("status") == SUCCESS_STATUS }
        ((success_count.to_f / sample.length) * 100).round(0)
      end

      def avg_duration_ms_last_50(runs)
        sample = recent_runs(runs, limit: 50).select { |run| run.fetch("status") == SUCCESS_STATUS }
        return nil if sample.empty?

        avg = sample.sum { |run| run.fetch("duration_ms").to_f } / sample.length
        avg.round(1)
      end

      def recent_runs(runs, limit:)
        runs.sort_by { |run| parse_time(run["created_at"]) }.last(limit)
      end

      def runs_trend_14d(runs)
        start_date = 13.days.ago.to_date
        counts = Hash.new(0)

        runs.each do |run|
          date = parse_time(run["created_at"]).to_date
          counts[date] += 1
        end

        (start_date..Date.current).map do |day|
          {day: day.strftime("%m-%d"), count: counts[day]}
        end
      end

      def pnl_trend(points)
        points
          .last(14)
          .map do |point|
            timestamp = Time.utc(point.fetch(:date).year, point.fetch(:date).month, point.fetch(:date).day)
            {
              label: timestamp.strftime("%m-%d %H:%M UTC"),
              timestamp: timestamp.iso8601,
              total_pnl_quote: format_decimal(point.fetch(:total))
            }
          end
      end

      def status_mix_30d(runs)
        window_runs = runs_in_window(runs, days: 30)
        counts = {
          queued: 0,
          running: 0,
          succeeded: 0,
          failed: 0
        }

        window_runs.each do |run|
          case run.fetch("status")
          when SUCCESS_STATUS
            counts[:succeeded] += 1
          when FAILED_STATUS, VALIDATION_STATUS
            counts[:failed] += 1
          else
            counts[:failed] += 1
          end
        end

        counts
      end

      def kpi_deltas(runs)
        recent_7 = runs_in_window(runs, days: 7)
        previous_7 = runs_between(runs, older_days: 14, newer_days: 7)
        recent_30 = runs_in_window(runs, days: 30)
        previous_30 = runs_between(runs, older_days: 60, newer_days: 30)

        {
          total_runs_7d: delta_metadata(recent_7.length, previous_7.length),
          total_runs_30d: delta_metadata(recent_30.length, previous_30.length),
          success_rate_last_50: delta_metadata(success_rate_last_50(recent_runs(runs, limit: 50)),
            success_rate_last_50(recent_runs(runs, limit: 100))),
          avg_duration_ms_last_50: delta_metadata(avg_duration_ms_last_50(recent_runs(runs, limit: 50)),
            avg_duration_ms_last_50(recent_runs(runs, limit: 100)),
            inverse_good: true)
        }
      end

      def runs_between(runs, older_days:, newer_days:)
        older_cutoff = Time.now.utc - (older_days * 86_400)
        newer_cutoff = Time.now.utc - (newer_days * 86_400)
        runs.select do |run|
          time = parse_time(run["created_at"])
          time >= older_cutoff && time < newer_cutoff
        end
      end

      def delta_metadata(current_value, previous_value, inverse_good: false)
        return {direction: "unknown", delta_abs: nil, delta_pct: nil} if previous_value.nil?
        return {direction: "unknown", delta_abs: nil, delta_pct: nil} if previous_value.to_f.zero?

        difference = current_value.to_f - previous_value.to_f
        direction = if difference.zero?
          "flat"
        else
          difference.positive? ? "up" : "down"
        end

        if inverse_good && !(direction == "flat")
          direction = (direction == "up") ? "down" : "up"
        end

        {
          direction: direction,
          delta_abs: difference.abs.round(1),
          delta_pct: ((difference / previous_value.to_f) * 100).abs.round(1)
        }
      end

      def latest_run_data(runs)
        run = runs.max_by { |entry| parse_time(entry["created_at"]) }
        return nil if run.nil?

        {
          id: run.fetch("id"),
          input_hash: "seed-#{run.fetch("id")}",
          duration_ms: run.fetch("duration_ms"),
          schema_version: "1.0",
          engine_version: "seed"
        }
      end

      def simulation_context_data(runs, positions)
        latest = latest_run_data(runs)
        return nil if latest.nil?

        accounts = positions.map { |entry| entry.fetch(:account_id) }.uniq
        markets = positions.map { |entry| entry.fetch(:market_id) }.uniq

        {
          dataset: "dashboard_seed",
          accounts_count: accounts.length,
          events_count: nil,
          markets: markets.join(", "),
          input_hash: latest.fetch(:input_hash),
          deterministic: "YES"
        }
      end

      def run_comparison_data(runs)
        success_runs = runs.select { |run| run.fetch("status") == SUCCESS_STATUS }
          .sort_by { |run| parse_time(run["created_at"]) }
        return nil if success_runs.length < 2

        current = success_runs[-1]
        previous = success_runs[-2]

        total_delta = current.fetch("pnl_total").to_f - previous.fetch("pnl_total").to_f
        realized_delta = current.fetch("pnl_realized").to_f - previous.fetch("pnl_realized").to_f
        unrealized_delta = current.fetch("pnl_unrealized").to_f - previous.fetch("pnl_unrealized").to_f

        {
          current_run_id: current.fetch("id"),
          previous_run_id: previous.fetch("id"),
          total_pnl_delta: format_decimal(total_delta),
          realized_delta: format_decimal(realized_delta),
          unrealized_delta: format_decimal(unrealized_delta),
          deterministic_result: deterministic_label(total_delta, realized_delta, unrealized_delta)
        }
      end

      def deterministic_label(total_delta, realized_delta, unrealized_delta)
        all_zero = [total_delta, realized_delta, unrealized_delta].all? { |value| value.to_f.zero? }
        return "Identical output for matching input hash." if all_zero

        "Differences detected between latest runs."
      end

      def input_traceability_data(runs)
        latest = latest_run_data(runs)
        return nil if latest.nil?

        {
          dataset: "dashboard_seed",
          input_hash: latest.fetch(:input_hash),
          artifacts: {
            result_json_path: relative_path(File.join(@seed_dir, "runs.json")),
            positions_csv_path: relative_path(File.join(@seed_dir, "positions.csv")),
            pnl_csv_path: relative_path(File.join(@seed_dir, "pnl.csv"))
          }
        }
      end

      def latest_global_data(points)
        latest = points.last
        return nil if latest.nil?

        total = latest.fetch(:total)
        {
          "totalPnLQuote" => format_decimal(total),
          "realizedNetPnLQuote" => format_decimal(latest.fetch(:realized)),
          "unrealizedPnLQuote" => format_decimal(latest.fetch(:unrealized)),
          "totalPnLUsd" => format_decimal(total * 1.02)
        }
      end

      def top_accounts_data(positions, points)
        return [] if positions.empty?

        total_base = points.last ? points.last.fetch(:total) : 120.0

        positions
          .group_by { |entry| entry.fetch(:account_id) }
          .map do |account_id, rows|
            exposure = rows.sum { |row| row.fetch(:quantity) * row.fetch(:avg_cost) }
            total = (exposure / 10_000.0) + (total_base / 20.0)
            {
              account_id: account_id,
              total_pnl_quote: BigDecimal(total.to_s),
              realized_net_pnl_quote: BigDecimal((total * 0.6).to_s),
              unrealized_pnl_quote: BigDecimal((total * 0.4).to_s)
            }
          end
          .sort_by { |entry| -entry.fetch(:total_pnl_quote) }
          .first(5)
      end

      def validation_error_entry(run)
        {
          source: "seed.validator",
          field: "input",
          message: "validation error",
          occurred_at: run.fetch("created_at"),
          correlation_id: "seed-#{run.fetch("id")}"
        }
      end

      def filter_by_source(entries, source)
        return entries if source.nil? || source.to_s.strip.empty?

        query = source.to_s.downcase.strip
        entries.select { |entry| entry.fetch(:source).to_s.downcase.include?(query) }
      end

      def filter_by_field(entries, field)
        return entries if field.nil? || field.to_s.strip.empty?

        query = field.to_s.downcase.strip
        entries.select { |entry| entry.fetch(:field).to_s.downcase.include?(query) }
      end

      def parse_time(value)
        Time.parse(value.to_s).utc
      rescue ArgumentError
        Time.at(0).utc
      end

      def format_decimal(value)
        format("%.2f", value.to_f)
      end

      def relative_path(path)
        pathname = Pathname(path.to_s)
        return pathname.to_s unless pathname.absolute?

        pathname.relative_path_from(Rails.root).to_s
      rescue ArgumentError
        pathname.to_s
      end
    end
  end
end
