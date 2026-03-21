require "rails_helper"

OVERVIEW_REQUIRED_KEYS = %w[
  contractVersion
  runKpis
  runsTrend14d
  statusMix30d
  latestRun
  globalSummary
  topAccounts
  legacy
].freeze

OVERVIEW_LEGACY_REQUIRED_KEYS = %w[
  total_runs_7d
  total_runs_30d
  success_rate_last_50
  avg_duration_ms_last_50
  runs_trend_14d
  status_mix_30d
  latest_run
  latest_global
  top_accounts
].freeze

RSpec.describe "Dashboard contract regression", type: :request do
  it "preserves required contract keys across dashboard endpoints" do
    overview = get_json("/dashboard/overview")
    expect(overview.keys).to include(*OVERVIEW_REQUIRED_KEYS)
    expect(overview.fetch("contractVersion")).to eq("v1")
    expect(overview.fetch("legacy").keys).to include(*OVERVIEW_LEGACY_REQUIRED_KEYS)

    top_accounts = get_json("/dashboard/top-accounts")
    expect(top_accounts.fetch("contractVersion")).to eq("v1")
    expect(top_accounts.keys).to contain_exactly("contractVersion", "topAccounts")

    ingestion_errors = get_json("/dashboard/ingestion-validation-errors")
    expect(ingestion_errors.fetch("contractVersion")).to eq("v1")
    expect(ingestion_errors.keys).to contain_exactly("contractVersion", "errors")
    expect(ingestion_errors.fetch("errors")).to all(include("source", "field", "message", "occurred_at",
      "correlation_id"))

    risk = get_json("/dashboard/risk")
    expect(risk.fetch("contractVersion")).to eq("v1")
    expect(risk.keys).to contain_exactly("contractVersion", "riskView")

    trend = get_json("/dashboard/trend")
    expect(trend.fetch("contractVersion")).to eq("v1")
    expect(trend.keys).to contain_exactly("contractVersion", "runsTrend14d")

    latest_run = get_json("/dashboard/latest-run")
    expect(latest_run.fetch("contractVersion")).to eq("v1")
    expect(latest_run.keys).to contain_exactly("contractVersion", "latestRun")
  end

  it "keeps all dashboard endpoints available under BFF degradation with fallback enabled" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_DASHBOARD_BFF_READ_ENABLED").and_return("1")
    allow(ENV).to receive(:[]).with("ADMIN_DASHBOARD_BFF_FALLBACK_ENABLED").and_return("1")

    failing_bff = instance_double("Admin::Dashboard::BffReadMetrics")
    allow(failing_bff).to receive(:call).and_raise(StandardError, "bff degraded")
    allow(Admin::Dashboard::BffReadMetrics).to receive(:new).and_return(failing_bff)

    required_payload_key_by_path = {
      "/dashboard/overview" => "runKpis",
      "/dashboard/top-accounts" => "topAccounts",
      "/dashboard/ingestion-validation-errors" => "errors",
      "/dashboard/risk" => "riskView",
      "/dashboard/trend" => "runsTrend14d",
      "/dashboard/latest-run" => "latestRun"
    }

    required_payload_key_by_path.each do |path, required_payload_key|
      get path, as: :json
      expect(response).to have_http_status(:ok), "Expected #{path} to remain available during fallback"

      parsed = JSON.parse(response.body)
      expect(parsed.fetch("contractVersion")).to eq("v1")
      expect(parsed).to include(required_payload_key)
    end
  end

  it "denies unauthenticated dashboard access when ADMIN_UI_TOKEN is configured" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_UI_TOKEN").and_return("ui-secret")

    [
      "/dashboard/overview",
      "/dashboard/top-accounts",
      "/dashboard/ingestion-validation-errors",
      "/dashboard/risk",
      "/dashboard/trend",
      "/dashboard/latest-run"
    ].each do |path|
      get path, as: :json
      expect(response).to have_http_status(:forbidden),
        "Expected #{path} to require auth when ADMIN_UI_TOKEN is configured"
    end
  end

  it "keeps dashboard contract keys stable for authenticated requests when ADMIN_UI_TOKEN is configured" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_UI_TOKEN").and_return("ui-secret")

    get "/dashboard/overview", headers: {"Authorization" => "Bearer ui-secret"}, as: :json

    expect(response).to have_http_status(:ok)
    parsed = JSON.parse(response.body)
    expect(parsed.keys).to include(*OVERVIEW_REQUIRED_KEYS)
    expect(parsed.fetch("contractVersion")).to eq("v1")
    expect(parsed.fetch("legacy").keys).to include(*OVERVIEW_LEGACY_REQUIRED_KEYS)
  end

  it "enforces mixed gate split between admin html session paths and dashboard machine paths" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_UI_TOKEN").and_return("ui-secret")

    get "/admin/overview", headers: {"X-Admin-Token" => "ui-secret"}
    expect(response).to have_http_status(:found)
    expect(response.headers["Location"]).to end_with("/")

    get "/admin/overview", headers: {"X-Admin-User" => "alice", "X-Admin-Role" => "viewer"}
    expect(response).to have_http_status(:ok)

    get "/dashboard/overview", headers: {"X-Admin-Token" => "ui-secret"}, as: :json
    expect(response).to have_http_status(:ok)
  end

  def get_json(path)
    get path, as: :json
    expect(response).to have_http_status(:ok)
    JSON.parse(response.body)
  end
end
