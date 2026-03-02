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
        expect(metrics[:latest_run][:id]).to eq(run.id)
        expect(metrics[:latest_global]["totalPnLQuote"]).to eq("10.5")
        expect(metrics[:top_accounts].first[:account_id]).to eq("acc-2")
      end
    end
  end
end
