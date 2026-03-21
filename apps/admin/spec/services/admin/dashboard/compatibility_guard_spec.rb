require "rails_helper"

RSpec.describe Admin::Dashboard::CompatibilityGuard do
  describe "#overview_payload" do
    it "adds contract metadata and validates required legacy keys" do
      guard = described_class.new

      payload = {
        "runKpis" => {},
        "runsTrend14d" => [],
        "statusMix30d" => {},
        "latestRun" => nil,
        "globalSummary" => nil,
        "topAccounts" => []
      }

      metrics = {
        total_runs_7d: 0,
        total_runs_30d: 0,
        success_rate_last_50: 0,
        avg_duration_ms_last_50: nil,
        runs_trend_14d: [],
        status_mix_30d: {queued: 0, running: 0, succeeded: 0, failed: 0},
        latest_run: nil,
        latest_global: nil,
        top_accounts: []
      }

      result = guard.overview_payload(payload: payload, metrics: metrics)

      expect(result.fetch("contractVersion")).to eq("v1")
      expect(result.fetch("legacy")).to include("total_runs_7d", "top_accounts")
    end

    it "raises when required overview keys are missing" do
      guard = described_class.new

      expect do
        guard.overview_payload(payload: {"runKpis" => {}}, metrics: {})
      end.to raise_error(ArgumentError, /Missing required compatibility keys/)
    end
  end

  describe "#widget_payload" do
    it "adds contract version and validates required widget key" do
      guard = described_class.new

      result = guard.widget_payload(payload: {"topAccounts" => []}, required_widget_keys: ["topAccounts"])

      expect(result).to include("contractVersion" => "v1", "topAccounts" => [])
    end
  end
end
