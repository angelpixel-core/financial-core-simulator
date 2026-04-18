require "rails_helper"
require "json"
require "tmpdir"

RSpec.describe Admin::DashboardMetrics do
  describe "#call" do
    it "returns safe empty-state metrics when no runs exist" do
      metrics = described_class.new.call

      expect(metrics[:total_runs_7d]).to eq(0)
      expect(metrics[:total_runs_30d]).to eq(0)
      expect(metrics[:total_trades]).to eq(0)
      expect(metrics[:total_trades_window]).to eq("all-time")
      expect(metrics[:success_rate_last_50]).to eq(0)
      expect(metrics[:avg_duration_ms_last_50]).to be_nil
      expect(metrics[:runs_trend_14d].length).to eq(14)
      expect(metrics[:status_mix_30d]).to eq(queued: 0, running: 0, succeeded: 0, failed: 0)
      expect(metrics[:latest_run]).to be_nil
      expect(metrics[:simulation_context]).to be_nil
      expect(metrics[:run_comparison]).to be_nil
      expect(metrics[:input_traceability]).to be_nil
      expect(metrics[:latest_global]).to be_nil
      expect(metrics[:top_accounts]).to eq([])
      expect(metrics[:pnl_trend]).to eq([])
      expect(metrics[:kpi_deltas]).to eq(
        total_runs_7d: {direction: "unknown", delta_abs: nil, delta_pct: nil},
        total_runs_30d: {direction: "unknown", delta_abs: nil, delta_pct: nil},
        success_rate_last_50: {direction: "unknown", delta_abs: nil, delta_pct: nil},
        avg_duration_ms_last_50: {direction: "unknown", delta_abs: nil, delta_pct: nil}
      )
    end

    it "computes run KPIs and top accounts from latest succeeded result" do
      old_run = Run.create!(status: :failed, created_at: 40.days.ago, input_json: {"schemaVersion" => "1.0"})
      old_run.update!(duration_ms: 100)

      run = Run.create!(status: :succeeded, created_at: 2.days.ago, input_json: {"schemaVersion" => "1.0"})
      run.update!(duration_ms: 200, input_hash: "abc123", schema_version: "1.0", engine_version: "0.1.0")

      Dir.mktmpdir do |dir|
        json_path = File.join(dir, "result.json")
        File.write(
          json_path,
          JSON.pretty_generate(
            {
              "global" => {
                "totalPnLQuote" => "10.5",
                "realizedNetPnLQuote" => "7.0",
                "unrealizedPnLQuote" => "3.5",
                "totalPnLUsd" => "10.5"
              },
              "accounts" => [
                {"accountId" => "acc-1",
                 "totals" => {"totalPnLQuote" => "5.5", "realizedNetPnLQuote" => "4.0",
                              "unrealizedPnLQuote" => "1.5"}},
                {"accountId" => "acc-2",
                 "totals" => {"totalPnLQuote" => "8.0", "realizedNetPnLQuote" => "5.0",
                              "unrealizedPnLQuote" => "3.0"}}
              ]
            }
          )
        )

        run.update!(artifacts: {"result_json_path" => json_path})

        metrics = described_class.new.call
        expect(metrics[:total_runs_7d]).to eq(1)
        expect(metrics[:total_runs_30d]).to eq(1)
        expect(metrics[:success_rate_last_50]).to eq(50)
        expect(metrics[:avg_duration_ms_last_50]).to eq(200.0)
        expect(metrics[:runs_trend_14d].map { |point| point[:count] }.sum).to eq(1)
        expect(metrics[:status_mix_30d]).to eq(queued: 0, running: 0, succeeded: 1, failed: 0)
        expect(metrics[:latest_run][:id]).to eq(run.id)
        expect(metrics[:simulation_context]).to include(
          dataset: "N/A",
          accounts_count: 2,
          events_count: nil,
          markets: nil,
          deterministic: "YES"
        )
        expect(metrics[:run_comparison]).to include(
          current_run_id: run.id,
          previous_run_id: nil,
          deterministic_result: "Comparison unavailable (need at least two succeeded runs)."
        )
        expect(metrics[:input_traceability]).to include(
          dataset: "N/A",
          input_hash: "abc123"
        )
        expect(metrics[:input_traceability][:artifacts]).to include(
          result_json_path: Pathname(json_path).relative_path_from(Rails.root).to_s,
          positions_csv_path: nil,
          pnl_csv_path: nil
        )
        expect(metrics[:latest_global]["totalPnLQuote"]).to eq("10.5")
        expect(metrics[:top_accounts].first[:account_id]).to eq("acc-2")
        expect(metrics[:pnl_trend].length).to eq(1)
        expect(metrics[:pnl_trend].first[:total_pnl_quote]).to eq("10.5")
        expect(metrics[:pnl_trend].first[:timestamp]).to be_a(String)
        expect(metrics[:kpi_deltas].keys).to contain_exactly(
          :total_runs_7d,
          :total_runs_30d,
          :success_rate_last_50,
          :avg_duration_ms_last_50
        )

        metrics[:kpi_deltas].each_value do |entry|
          expect(entry.keys).to contain_exactly(:direction, :delta_abs, :delta_pct)
        end
      end
    end

    it "prefers live state metrics for latest global and top accounts when available" do
      run = Run.create!(status: :succeeded, created_at: 1.day.ago, input_json: {"schemaVersion" => "1.0"})
      run.update!(duration_ms: 120, input_hash: "hash-live", schema_version: "1.0", engine_version: "0.1.0")

      Dir.mktmpdir do |dir|
        json_path = File.join(dir, "result.json")
        File.write(
          json_path,
          JSON.pretty_generate(
            {
              "global" => {"totalPnLQuote" => "5.0", "realizedNetPnLQuote" => "3.0", "unrealizedPnLQuote" => "2.0"},
              "accounts" => [
                {"accountId" => "acc-artifact",
                 "totals" => {"totalPnLQuote" => "5.0", "realizedNetPnLQuote" => "3.0",
                              "unrealizedPnLQuote" => "2.0"}}
              ]
            }
          )
        )
        run.update!(artifacts: {"result_json_path" => json_path})

        live_provider = class_double("Admin::LiveStateMetrics").as_stubbed_const
        live_instance = instance_double(
          "Admin::LiveStateMetrics",
          call: {
            checkpoint_timeline_seq: 10,
            latest_global: {"totalPnLQuote" => "77.0", "realizedNetPnLQuote" => "70.0",
                            "unrealizedPnLQuote" => "7.0"},
            top_accounts: [
              {
                account_id: "acc-live",
                total_pnl_quote: BigDecimal("77.0"),
                realized_net_pnl_quote: BigDecimal("70.0"),
                unrealized_pnl_quote: BigDecimal("7.0")
              }
            ]
          }
        )
        expect(live_provider).to receive(:new).and_return(live_instance)

        metrics = described_class.new.call

        expect(metrics[:latest_global]["totalPnLQuote"]).to eq("77.0")
        expect(metrics[:top_accounts].map { |entry| entry[:account_id] }).to eq(["acc-live"])
      end
    end

    it "falls back to artifact-backed metrics when live source raises" do
      run = Run.create!(status: :succeeded, created_at: 1.day.ago, input_json: {"schemaVersion" => "1.0"})

      Dir.mktmpdir do |dir|
        json_path = File.join(dir, "result.json")
        File.write(
          json_path,
          JSON.pretty_generate(
            {
              "global" => {"totalPnLQuote" => "9.0", "realizedNetPnLQuote" => "8.0", "unrealizedPnLQuote" => "1.0"},
              "accounts" => [
                {"accountId" => "acc-fallback",
                 "totals" => {"totalPnLQuote" => "9.0", "realizedNetPnLQuote" => "8.0",
                              "unrealizedPnLQuote" => "1.0"}}
              ]
            }
          )
        )
        run.update!(artifacts: {"result_json_path" => json_path})

        live_provider = class_double("Admin::LiveStateMetrics").as_stubbed_const
        live_instance = instance_double("Admin::LiveStateMetrics")
        expect(live_provider).to receive(:new).and_return(live_instance)
        expect(live_instance).to receive(:call).and_raise(StandardError, "live unavailable")

        metrics = described_class.new.call

        expect(metrics[:latest_global]["totalPnLQuote"]).to eq("9.0")
        expect(metrics[:top_accounts].map { |entry| entry[:account_id] }).to eq(["acc-fallback"])
      end
    end

    it "falls back to artifact-backed top accounts when live data has no totals" do
      run = Run.create!(status: :succeeded, created_at: 1.day.ago, input_json: {"schemaVersion" => "1.0"})

      Dir.mktmpdir do |dir|
        json_path = File.join(dir, "result.json")
        File.write(
          json_path,
          JSON.pretty_generate(
            {
              "global" => {"totalPnLQuote" => "9.0", "realizedNetPnLQuote" => "8.0", "unrealizedPnLQuote" => "1.0"},
              "accounts" => [
                {"accountId" => "acc-fallback",
                 "totals" => {"totalPnLQuote" => "9.0", "realizedNetPnLQuote" => "8.0",
                              "unrealizedPnLQuote" => "1.0"}}
              ]
            }
          )
        )
        run.update!(artifacts: {"result_json_path" => json_path})

        live_provider = class_double("Admin::LiveStateMetrics").as_stubbed_const
        live_instance = instance_double(
          "Admin::LiveStateMetrics",
          call: {
            checkpoint_timeline_seq: 6,
            latest_global: nil,
            top_accounts: nil
          }
        )
        expect(live_provider).to receive(:new).and_return(live_instance)

        metrics = described_class.new.call

        expect(metrics[:top_accounts].map { |entry| entry[:account_id] }).to eq(["acc-fallback"])
      end
    end

    it "reports avg duration delta direction with inverse-good semantics" do
      50.times do
        run = Run.create!(status: :succeeded, created_at: 80.days.ago, input_json: {"schemaVersion" => "1.0"})
        run.update!(duration_ms: 200)
      end

      50.times do
        run = Run.create!(status: :succeeded, created_at: 1.day.ago, input_json: {"schemaVersion" => "1.0"})
        run.update!(duration_ms: 100)
      end

      metrics = described_class.new.call
      expect(metrics[:avg_duration_ms_last_50]).to eq(100.0)
      expect(metrics[:kpi_deltas][:avg_duration_ms_last_50][:direction]).to eq("up")
      expect(metrics[:kpi_deltas][:avg_duration_ms_last_50][:delta_abs]).to eq(100.0)
      expect(metrics[:kpi_deltas][:avg_duration_ms_last_50][:delta_pct]).to eq(50.0)
    end

    it "includes only succeeded runs with canonical result and valid totalPnLQuote in pnl trend" do
      failed_run = Run.create!(status: :failed, created_at: 3.days.ago, input_json: {"schemaVersion" => "1.0"})
      failed_run.update!(artifacts: {"result_json_path" => "/tmp/missing.json"})

      missing_artifact_run = Run.create!(status: :succeeded, created_at: 2.days.ago,
        input_json: {"schemaVersion" => "1.0"})
      missing_artifact_run.update!(artifacts: {"result_json_path" => "/tmp/missing.json"})

      invalid_pnl_run = Run.create!(status: :succeeded, created_at: 1.day.ago, input_json: {"schemaVersion" => "1.0"})

      valid_run = Run.create!(
        status: :succeeded,
        created_at: Time.zone.parse("2026-03-14T03:00:00Z"),
        valuation_timestamp: Time.zone.parse("2026-03-14T04:00:00Z"),
        input_json: {"schemaVersion" => "1.0"}
      )

      Dir.mktmpdir do |dir|
        invalid_path = File.join(dir, "invalid.json")
        valid_path = File.join(dir, "valid.json")

        File.write(invalid_path, JSON.pretty_generate({"global" => {"totalPnLQuote" => "bad"}}))
        File.write(valid_path, JSON.pretty_generate({"global" => {"totalPnLQuote" => "42.25"}}))

        invalid_pnl_run.update!(artifacts: {"result_json_path" => invalid_path})
        valid_run.update!(artifacts: {"result_json_path" => valid_path})

        metrics = described_class.new.call

        expect(metrics[:pnl_trend].length).to eq(1)
        expect(metrics[:pnl_trend].first).to include(
          total_pnl_quote: "42.25",
          timestamp: "2026-03-14T04:00:00Z",
          label: "03-14 04:00 UTC"
        )
      end
    end

    it "computes total trades without distinct undercount and supports window selection" do
      run = Run.create!(status: :succeeded, created_at: 1.day.ago,
        input_json: {"schemaVersion" => "1.0", "trades" => []})

      snapshot_day_31 = RunSnapshot.create!(run: run, operational_date: 31.days.ago.to_date, reporting_currency: "USD")
      snapshot_day_2 = RunSnapshot.create!(run: run, operational_date: 2.days.ago.to_date, reporting_currency: "USD")
      snapshot_day_1 = RunSnapshot.create!(run: run, operational_date: 1.day.ago.to_date, reporting_currency: "USD")

      RunDailyVolume.create!(run_snapshot: snapshot_day_31, notional_volume: 10, trade_count: 6, unit_type: "quote",
        unit_code: "USD")
      RunDailyVolume.create!(run_snapshot: snapshot_day_2, notional_volume: 20, trade_count: 6, unit_type: "quote",
        unit_code: "USD")
      RunDailyVolume.create!(run_snapshot: snapshot_day_1, notional_volume: 30, trade_count: 8, unit_type: "quote",
        unit_code: "USD")

      all_time_metrics = described_class.new.call
      thirty_day_metrics = described_class.new.call(trades_window: "30d")

      expect(all_time_metrics[:total_trades]).to eq(20)
      expect(all_time_metrics[:total_trades_window]).to eq("all-time")
      expect(thirty_day_metrics[:total_trades]).to eq(14)
      expect(thirty_day_metrics[:total_trades_window]).to eq("30d")
    end

    it "computes run comparison deltas and traceability fields from latest and previous succeeded runs" do
      previous_run = Run.create!(
        status: :succeeded,
        created_at: 2.days.ago,
        input_hash: "same-hash",
        input_json: {
          "dataset" => "demo_input.json",
          "events" => [{"marketId" => "BTC-USD"}, {"marketId" => "ETH-USD"}],
          "accounts" => [{"accountId" => "acc-1"}, {"accountId" => "acc-2"}]
        }
      )
      latest_run = Run.create!(
        status: :succeeded,
        created_at: 1.day.ago,
        input_hash: "same-hash",
        input_json: {
          "dataset" => "demo_input.json",
          "events" => [{"marketId" => "BTC-USD"}, {"marketId" => "ETH-USD"}],
          "accounts" => [{"accountId" => "acc-1"}, {"accountId" => "acc-2"}]
        }
      )

      Dir.mktmpdir do |dir|
        previous_path = File.join(dir, "previous.json")
        latest_path = File.join(dir, "latest.json")
        positions_path = File.join(dir, "positions.csv")
        pnl_path = File.join(dir, "pnl.csv")

        File.write(previous_path, JSON.pretty_generate({
          "global" => {
            "totalPnLQuote" => "40.00",
            "realizedNetPnLQuote" => "20.00",
            "unrealizedPnLQuote" => "20.00"
          }
        }))
        File.write(latest_path, JSON.pretty_generate({
          "global" => {
            "totalPnLQuote" => "42.25",
            "realizedNetPnLQuote" => "21.00",
            "unrealizedPnLQuote" => "21.25"
          }
        }))
        File.write(positions_path, "account,qty\nacc-1,10\n")
        File.write(pnl_path, "account,total\nacc-1,42.25\n")

        previous_run.update!(artifacts: {"result_json_path" => previous_path})
        latest_run.update!(artifacts: {
          "result_json_path" => latest_path,
          "positions_csv_path" => positions_path,
          "pnl_csv_path" => pnl_path
        })

        metrics = described_class.new.call

        expect(metrics[:simulation_context]).to include(
          dataset: "demo_input.json",
          accounts_count: 2,
          events_count: 2,
          markets: "BTC-USD, ETH-USD",
          input_hash: "same-hash",
          deterministic: "YES"
        )

        expect(metrics[:run_comparison]).to include(
          current_run_id: latest_run.id,
          previous_run_id: previous_run.id,
          total_pnl_delta: "2.25",
          realized_delta: "1.0",
          unrealized_delta: "1.25"
        )
        expect(metrics[:run_comparison][:deterministic_result]).to eq("Differences detected between latest runs.")

        expect(metrics[:input_traceability]).to include(
          dataset: "demo_input.json",
          input_hash: "same-hash"
        )
        expect(metrics[:input_traceability][:artifacts]).to include(
          result_json_path: Pathname(latest_path).relative_path_from(Rails.root).to_s,
          positions_csv_path: Pathname(positions_path).relative_path_from(Rails.root).to_s,
          pnl_csv_path: Pathname(pnl_path).relative_path_from(Rails.root).to_s
        )
      end
    end
  end
end
