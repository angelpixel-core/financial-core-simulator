require "rails_helper"

RSpec.describe "Dashboard contract regression", type: :request do
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

  it "preserves required contract keys across dashboard endpoints" do
    overview = get_json("/dashboard/overview")
    expect(overview.keys).to include(*OVERVIEW_REQUIRED_KEYS)
    expect(overview.fetch("legacy").keys).to include(*OVERVIEW_LEGACY_REQUIRED_KEYS)

    expect(get_json("/dashboard/top-accounts").keys).to contain_exactly("contractVersion", "topAccounts")
    expect(get_json("/dashboard/risk").keys).to contain_exactly("contractVersion", "riskView")
    expect(get_json("/dashboard/trend").keys).to contain_exactly("contractVersion", "runsTrend14d")
    expect(get_json("/dashboard/latest-run").keys).to contain_exactly("contractVersion", "latestRun")
  end

  it "keeps all dashboard endpoints available under BFF degradation with fallback enabled" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_DASHBOARD_BFF_READ_ENABLED").and_return("1")
    allow(ENV).to receive(:[]).with("ADMIN_DASHBOARD_BFF_FALLBACK_ENABLED").and_return("1")

    failing_bff = instance_double("Admin::Dashboard::BffReadMetrics")
    allow(failing_bff).to receive(:call).and_raise(StandardError, "bff degraded")
    allow(Admin::Dashboard::BffReadMetrics).to receive(:new).and_return(failing_bff)

    %w[
      /dashboard/overview
      /dashboard/top-accounts
      /dashboard/risk
      /dashboard/trend
      /dashboard/latest-run
    ].each do |path|
      get path, as: :json
      expect(response).to have_http_status(:ok), "Expected #{path} to remain available during fallback"
    end
  end

  def get_json(path)
    get path, as: :json
    expect(response).to have_http_status(:ok)
    JSON.parse(response.body)
  end
end
