require "rails_helper"

RSpec.describe "Dashboard compatibility contract", type: :request do
  it "keeps required legacy overview keys while exposing additive UI-ready keys" do
    get "/dashboard/overview", as: :json

    expect(response).to have_http_status(:ok)

    parsed = JSON.parse(response.body)
    expect(parsed).to include("contractVersion", "runKpis", "runsTrend14d", "statusMix30d", "latestRun",
      "globalSummary", "topAccounts", "legacy")
    expect(parsed.fetch("contractVersion")).to eq("v1")
    expect(parsed.fetch("legacy")).to include(
      "total_runs_7d",
      "total_runs_30d",
      "success_rate_last_50",
      "avg_duration_ms_last_50",
      "runs_trend_14d",
      "status_mix_30d",
      "latest_run",
      "latest_global",
      "top_accounts"
    )
  end

  it "keeps widget responses additive with contract version marker" do
    get "/dashboard/top-accounts", as: :json

    expect(response).to have_http_status(:ok)

    parsed = JSON.parse(response.body)
    expect(parsed).to include("contractVersion", "topAccounts")
    expect(parsed.fetch("contractVersion")).to eq("v1")
  end

  it "keeps ingestion validation errors response additive with contract version marker" do
    get "/dashboard/ingestion-validation-errors", as: :json

    expect(response).to have_http_status(:ok)

    parsed = JSON.parse(response.body)
    expect(parsed).to include("contractVersion", "errors")
    expect(parsed.fetch("contractVersion")).to eq("v1")
    expect(parsed.fetch("errors")).to all(include("source", "field", "message", "occurred_at", "correlation_id"))
  end
end
