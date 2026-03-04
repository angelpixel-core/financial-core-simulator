require "rails_helper"
require "json"
require "tmpdir"

RSpec.describe Admin::DashboardMetrics do
  describe "#call" do
    it "returns safe empty-state metrics when no runs exist" do
      metrics = described_class.new.call

      expect(metrics[:total_runs_7d]).to eq(0)
      expect(metrics[:total_runs_30d]).to eq(0)
      expect(metrics[:success_rate_last_50]).to eq(0)
      expect(metrics[:avg_duration_ms_last_50]).to be_nil
      expect(metrics[:runs_trend_14d].length).to eq(14)
      expect(metrics[:status_mix_30d]).to eq(queued: 0, running: 0, succeeded: 0, failed: 0)
      expect(metrics[:latest_run]).to be_nil
      expect(metrics[:latest_global]).to be_nil
      expect(metrics[:top_accounts]).to eq([])
    end

    it "computes run KPIs and top accounts from latest succeeded result" do
      old_run = Run.create!(status: :failed, created_at: 40.days.ago, input_json: { "schemaVersion" => "1.0" })
      old_run.update!(duration_ms: 100)

      run = Run.create!(status: :succeeded, created_at: 2.days.ago, input_json: { "schemaVersion" => "1.0" })
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
                { "accountId" => "acc-1", "totals" => { "totalPnLQuote" => "5.5", "realizedNetPnLQuote" => "4.0", "unrealizedPnLQuote" => "1.5" } },
                { "accountId" => "acc-2", "totals" => { "totalPnLQuote" => "8.0", "realizedNetPnLQuote" => "5.0", "unrealizedPnLQuote" => "3.0" } }
              ]
            }
          )
        )

        run.update!(artifacts: { "result_json_path" => json_path })

        metrics = described_class.new.call
        expect(metrics[:total_runs_7d]).to eq(1)
        expect(metrics[:total_runs_30d]).to eq(1)
        expect(metrics[:success_rate_last_50]).to eq(50)
        expect(metrics[:avg_duration_ms_last_50]).to eq(200.0)
        expect(metrics[:runs_trend_14d].map { |point| point[:count] }.sum).to eq(1)
        expect(metrics[:status_mix_30d]).to eq(queued: 0, running: 0, succeeded: 1, failed: 0)
        expect(metrics[:latest_run][:id]).to eq(run.id)
        expect(metrics[:latest_global]["totalPnLQuote"]).to eq("10.5")
        expect(metrics[:top_accounts].first[:account_id]).to eq("acc-2")
      end
    end

    it "prefers live state metrics for latest global and top accounts when available" do
      run = Run.create!(status: :succeeded, created_at: 1.day.ago, input_json: { "schemaVersion" => "1.0" })
      run.update!(duration_ms: 120, input_hash: "hash-live", schema_version: "1.0", engine_version: "0.1.0")

      Dir.mktmpdir do |dir|
        json_path = File.join(dir, "result.json")
        File.write(
          json_path,
          JSON.pretty_generate(
            {
              "global" => { "totalPnLQuote" => "5.0", "realizedNetPnLQuote" => "3.0", "unrealizedPnLQuote" => "2.0" },
              "accounts" => [
                { "accountId" => "acc-artifact", "totals" => { "totalPnLQuote" => "5.0", "realizedNetPnLQuote" => "3.0", "unrealizedPnLQuote" => "2.0" } }
              ]
            }
          )
        )
        run.update!(artifacts: { "result_json_path" => json_path })

        live_provider = class_double("Admin::LiveStateMetrics").as_stubbed_const
        live_instance = instance_double(
          "Admin::LiveStateMetrics",
          call: {
            checkpoint_timeline_seq: 10,
            latest_global: { "totalPnLQuote" => "77.0", "realizedNetPnLQuote" => "70.0", "unrealizedPnLQuote" => "7.0" },
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
        expect(metrics[:top_accounts].map { |entry| entry[:account_id] }).to eq([ "acc-live" ])
      end
    end

    it "falls back to artifact-backed metrics when live source raises" do
      run = Run.create!(status: :succeeded, created_at: 1.day.ago, input_json: { "schemaVersion" => "1.0" })

      Dir.mktmpdir do |dir|
        json_path = File.join(dir, "result.json")
        File.write(
          json_path,
          JSON.pretty_generate(
            {
              "global" => { "totalPnLQuote" => "9.0", "realizedNetPnLQuote" => "8.0", "unrealizedPnLQuote" => "1.0" },
              "accounts" => [
                { "accountId" => "acc-fallback", "totals" => { "totalPnLQuote" => "9.0", "realizedNetPnLQuote" => "8.0", "unrealizedPnLQuote" => "1.0" } }
              ]
            }
          )
        )
        run.update!(artifacts: { "result_json_path" => json_path })

        live_provider = class_double("Admin::LiveStateMetrics").as_stubbed_const
        live_instance = instance_double("Admin::LiveStateMetrics")
        expect(live_provider).to receive(:new).and_return(live_instance)
        expect(live_instance).to receive(:call).and_raise(StandardError, "live unavailable")

        metrics = described_class.new.call

        expect(metrics[:latest_global]["totalPnLQuote"]).to eq("9.0")
        expect(metrics[:top_accounts].map { |entry| entry[:account_id] }).to eq([ "acc-fallback" ])
      end
    end

    it "falls back to artifact-backed top accounts when live data has no totals" do
      run = Run.create!(status: :succeeded, created_at: 1.day.ago, input_json: { "schemaVersion" => "1.0" })

      Dir.mktmpdir do |dir|
        json_path = File.join(dir, "result.json")
        File.write(
          json_path,
          JSON.pretty_generate(
            {
              "global" => { "totalPnLQuote" => "9.0", "realizedNetPnLQuote" => "8.0", "unrealizedPnLQuote" => "1.0" },
              "accounts" => [
                { "accountId" => "acc-fallback", "totals" => { "totalPnLQuote" => "9.0", "realizedNetPnLQuote" => "8.0", "unrealizedPnLQuote" => "1.0" } }
              ]
            }
          )
        )
        run.update!(artifacts: { "result_json_path" => json_path })

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

        expect(metrics[:top_accounts].map { |entry| entry[:account_id] }).to eq([ "acc-fallback" ])
      end
    end
  end
end
