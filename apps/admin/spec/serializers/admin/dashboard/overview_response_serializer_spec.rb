require "rails_helper"

RSpec.describe Admin::Dashboard::OverviewResponseSerializer do
  it "serializes overview payload through compatibility guard" do
    guard = instance_double("Admin::Dashboard::CompatibilityGuard")
    serializer = described_class.new(compatibility_guard: guard)
    metrics_payload = {
      total_runs_7d: 1,
      total_runs_30d: 2,
      success_rate_last_50: 50,
      avg_duration_ms_last_50: 120.5,
      runs_trend_14d: [ { day: "03-05", count: 1 } ],
      status_mix_30d: { queued: 0, running: 0, succeeded: 1, failed: 0 },
      latest_run: { id: 1 },
      latest_global: { "totalPnLQuote" => "10.0" },
      top_accounts: []
    }

    expect(guard).to receive(:overview_payload) do |payload:, metrics:|
      expect(payload).to include("runKpis", "runsTrend14d", "statusMix30d", "latestRun", "globalSummary", "topAccounts")
      expect(metrics).to eq(metrics_payload)
      { "contractVersion" => "v1" }
    end

    expect(serializer.serialize(metrics: metrics_payload)).to eq("contractVersion" => "v1")
  end

  it "normalizes nil metrics to additive empty structures" do
    serializer = described_class.new

    payload = serializer.serialize(metrics: {
      total_runs_7d: 0,
      total_runs_30d: 0,
      success_rate_last_50: 0,
      avg_duration_ms_last_50: nil,
      runs_trend_14d: nil,
      status_mix_30d: nil,
      latest_run: nil,
      latest_global: nil,
      top_accounts: nil
    })

    expect(payload.fetch("runsTrend14d")).to eq([])
    expect(payload.fetch("statusMix30d")).to eq({})
    expect(payload.fetch("latestRun")).to eq({})
    expect(payload.fetch("globalSummary")).to eq({})
    expect(payload.fetch("topAccounts")).to eq([])
  end
end
