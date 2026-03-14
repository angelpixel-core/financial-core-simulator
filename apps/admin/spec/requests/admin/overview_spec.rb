require "rails_helper"
require "bcrypt"
require "json"
require "tmpdir"

RSpec.describe "Admin overview", type: :request do
  it "renders empty state without exploding when no runs exist" do
    get "/admin/overview", headers: admin_session_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Financial Overview")
    expect(response.body).to include("SYSTEM")
    expect(response.body).to include("LATEST RUN")
    expect(response.body).to include("FINANCIAL")
    expect(response.body).to include("DATA QUALITY")
    expect(response.body).to include("No succeeded runs yet.")
    expect(response.body).to include("Run trend (14d)")
    expect(response.body).to include("Status mix (30d)")
    expect(response.body).to include("data-controller=\"poll\"")
  end

  it "renders authenticated shell identity and logout affordance on overview" do
    Account.create!(
      email: "ops-shell@example.com",
      status: :verified,
      password_hash: BCrypt::Password.create("secret-pass")
    )

    post "/admin/login", params: { email: "ops-shell@example.com", password: "secret-pass" }
    expect(response).to have_http_status(:found)

    get "/admin/overview"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("ops-shell@example.com")
    expect(response.body).to include("/admin/logout")
  end

  it "does not expose authenticated shell controls on landing and login" do
    get "/"

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("/admin/logout")

    get "/admin/login"

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("/admin/logout")
  end

  it "renders drilldown links for runs activity, latest run, top accounts, and ingestion errors" do
    run = Run.create!(
      status: :succeeded,
      input_hash: "abc123",
      schema_version: "1.0",
      engine_version: "1.0"
    )

    get "/admin/overview", headers: admin_session_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("View runs trend")
    expect(response.body).to include("View status details")
    expect(response.body).to include("View latest run")
    expect(response.body).to include("View top accounts")
    expect(response.body).to include("View ingestion errors")

    expect(response.body).to include(%(href="#{admin_overview_runs_trend_path}"))
    expect(response.body).to include(%(href="#{admin_overview_status_mix_path}"))
    expect(response.body).to include(%(href="/admin/resources/runs/#{run.id}"))
    expect(response.body).to include(%(href="#{admin_overview_top_accounts_path}"))
    expect(response.body).to include(%(href="#{admin_overview_ingestion_validation_errors_path}"))
  end

  it "renders dedicated runs trend and status mix pages" do
    get admin_overview_runs_trend_path, headers: admin_session_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Runs Trend (14d)")
    expect(response.body).to include("Run trend (14d)")
    expect(response.body).to include('data-controller="run-trend-chart"')
    expect(response.body).to include('data-run-trend-chart-target="chart"')
    expect(response.body).to include('data-run-trend-chart-target="fallback"')
    expect(response.body).to include('data-run-trend-chart-animation-mode-value="proportional"')
    expect(response.body).to include('data-run-trend-chart-base-duration-value="260"')
    expect(response.body).to include('data-run-trend-chart-max-extra-duration-value="540"')

    get admin_overview_status_mix_path, headers: admin_session_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Status Mix (30d)")
    expect(response.body).to include("Status mix (30d)")
  end

  it "keeps trend chart hook and fallback nodes coexisting in overview" do
    get "/admin/overview", headers: admin_session_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('data-controller="run-trend-chart"')
    expect(response.body).to include('data-run-trend-chart-target="chart"')
    expect(response.body).to include('data-run-trend-chart-target="fallback"')
    expect(response.body).to include('data-run-trend-chart-animation-mode-value="proportional"')
    expect(response.body).to include('data-run-trend-chart-base-duration-value="260"')
    expect(response.body).to include('data-run-trend-chart-max-extra-duration-value="540"')
  end

  it "renders count-up data hooks for all system KPI cards with numeric values" do
    run = Run.create!(status: :succeeded, created_at: 1.day.ago, input_json: { "schemaVersion" => "1.0" })
    run.update!(duration_ms: 123)

    get "/admin/overview", headers: admin_session_headers

    expect(response).to have_http_status(:ok)
    expect(response.body.scan('data-controller="kpi-counter"').size).to eq(4)
    expect(response.body.scan('data-kpi-counter-target="value"').size).to eq(4)
    expect(response.body).to include('data-kpi-counter-kind-value="integer"')
    expect(response.body).to include('data-kpi-counter-kind-value="percent"')
    expect(response.body).to include('data-kpi-counter-kind-value="milliseconds"')
    expect(response.body).to include('data-kpi-counter-final-value="1"')
    expect(response.body).to include('data-kpi-counter-final-value="100"')
    expect(response.body).to include('data-kpi-counter-final-value="123.0"')
  end

  it "renders top accounts partial endpoint" do
    get "/admin/overview/top-accounts", headers: admin_session_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Top accounts (live)")
    expect(response.body).to include("Back to overview")
  end

  it "preserves selected run and critical filters across drilldown navigation" do
    get "/admin/overview", params: {
      selected_run: "run-ops-42",
      run_status: "succeeded",
      validation_status: "verified",
      date_range: "last_24h",
      correlation_id: "corr-42"
    }, headers: admin_session_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("selected_run=run-ops-42")
    expect(response.body).to include("run_status=succeeded")
    expect(response.body).to include("validation_status=verified")
    expect(response.body).to include("date_range=last_24h")
    expect(response.body).to include("correlation_id=corr-42")

    get "/admin/overview/top-accounts", headers: admin_session_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("selected_run=run-ops-42")
    expect(response.body).to include("run_status=succeeded")
    expect(response.body).to include("validation_status=verified")
    expect(response.body).to include("date_range=last_24h")
    expect(response.body).to include("correlation_id=corr-42")
  end

  it "renders top accounts fragment for xhr polling" do
    get "/admin/overview/top-accounts", headers: admin_session_headers.merge("X-Requested-With" => "XMLHttpRequest")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Top accounts (live)")
    expect(response.body).not_to include("Back to overview")
  end

  it "redirects unauthenticated html overview to root when ADMIN_UI_TOKEN is set" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_UI_TOKEN").and_return("ui-secret")

    get "/admin/overview"

    expect(response).to have_http_status(:found)
    expect(response.headers["Location"]).to end_with("/")
  end

  it "redirects unauthenticated html top accounts endpoint to root when ADMIN_UI_TOKEN is set" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_UI_TOKEN").and_return("ui-secret")

    get "/admin/overview/top-accounts"

    expect(response).to have_http_status(:found)
    expect(response.headers["Location"]).to end_with("/")
  end

  it "redirects unauthenticated html overview detail endpoints to root when ADMIN_UI_TOKEN is set" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_UI_TOKEN").and_return("ui-secret")

    [
      "/admin/overview/runs-trend",
      "/admin/overview/status-mix",
      "/admin/overview/ingestion-validation-errors"
    ].each do |path|
      get path

      expect(response).to have_http_status(:found), "Expected #{path} to redirect"
      expect(response.headers["Location"]).to end_with("/"), "Expected #{path} to redirect to root"
    end
  end

  it "redirects unauthenticated top accounts xhr endpoint to root when ADMIN_UI_TOKEN is set" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_UI_TOKEN").and_return("ui-secret")

    get "/admin/overview/top-accounts", headers: { "X-Requested-With" => "XMLHttpRequest" }

    expect(response).to have_http_status(:found)
    expect(response.headers["Location"]).to end_with("/")
  end

  it "keeps /admin and /dashboard protected-surface contracts stable without ADMIN_UI_TOKEN" do
    get "/admin/overview"

    expect(response).to have_http_status(:found)
    expect(response.headers["Location"]).to end_with("/")

    get "/dashboard/overview", as: :json

    expect(response).to have_http_status(:ok)
  end

  it "keeps /admin and /dashboard protected-surface contracts stable with ADMIN_UI_TOKEN" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_UI_TOKEN").and_return("ui-secret")

    get "/admin/overview"

    expect(response).to have_http_status(:found)
    expect(response.headers["Location"]).to end_with("/")

    get "/dashboard/overview", as: :json

    expect(response).to have_http_status(:forbidden)
  end

  it "denies unauthenticated access across overview and dashboard protected surfaces when ADMIN_UI_TOKEN is set" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_UI_TOKEN").and_return("ui-secret")

    [
      "/admin/overview",
      "/admin/overview/top-accounts",
      "/dashboard/overview",
      "/dashboard/top-accounts",
      "/dashboard/ingestion-validation-errors"
    ].each do |path|
      get path, as: :json

      expect(response).to have_http_status(:forbidden), "Expected #{path} to require authentication"
    end
  end

  it "keeps admin html overview on session gate when ADMIN_UI_TOKEN is provided and redirects to root" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_UI_TOKEN").and_return("ui-secret")

    get "/admin/overview", headers: { "X-Admin-Token" => "ui-secret" }

    expect(response).to have_http_status(:found)
    expect(response.headers["Location"]).to end_with("/")
  end

  it "allows access via role-based policy when ADMIN_UI_TOKEN is set" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_UI_TOKEN").and_return("ui-secret")

    get "/admin/overview", headers: { "X-Admin-User" => "alice", "X-Admin-Role" => "viewer" }

    expect(response).to have_http_status(:ok)
  end

  context "when live metrics source is available/unavailable" do
    it "prefers live metrics when live source is available" do
      Dir.mktmpdir do |dir|
        run_with_accounts_json(dir: dir, account_id: "acc-artifact", total_pnl_quote: "3.0")

        live_provider = class_double("Admin::LiveStateMetrics").as_stubbed_const
        live_instance = instance_double("Admin::LiveStateMetrics", call: live_metrics_for(account_id: "acc-live", total_pnl_quote: "77.0"))
        expect(live_provider).to receive(:new).and_return(live_instance)

        get "/admin/overview", headers: admin_session_headers

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("acc-live")
        expect(response.body).not_to include("acc-artifact")
      end
    end

    it "falls back to artifact metrics when live source is unavailable" do
      Dir.mktmpdir do |dir|
        run_with_accounts_json(dir: dir, account_id: "acc-artifact", total_pnl_quote: "11.0")

        live_provider = class_double("Admin::LiveStateMetrics").as_stubbed_const
        live_instance = instance_double("Admin::LiveStateMetrics")
        expect(live_provider).to receive(:new).and_return(live_instance)
        expect(live_instance).to receive(:call).and_raise(StandardError, "live unavailable")

        get "/admin/overview", headers: admin_session_headers

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("acc-artifact")
      end
    end
  end

  def run_with_accounts_json(dir:, account_id:, total_pnl_quote:)
    run = Run.create!(status: :succeeded, input_json: { "schemaVersion" => "1.0" })
    path = File.join(dir, "result.json")
    File.write(path, JSON.pretty_generate(result_payload(account_id: account_id, total_pnl_quote: total_pnl_quote)))
    run.update!(artifacts: { "result_json_path" => path })
    run
  end

  def result_payload(account_id:, total_pnl_quote:)
    {
      "global" => {
        "totalPnLQuote" => total_pnl_quote,
        "realizedNetPnLQuote" => total_pnl_quote,
        "unrealizedPnLQuote" => "0.0",
        "totalPnLUsd" => total_pnl_quote
      },
      "accounts" => [
        {
          "accountId" => account_id,
          "totals" => {
            "totalPnLQuote" => total_pnl_quote,
            "realizedNetPnLQuote" => total_pnl_quote,
            "unrealizedPnLQuote" => "0.0"
          }
        }
      ]
    }
  end

  def live_metrics_for(account_id:, total_pnl_quote:)
    {
      total_runs_7d: 0,
      total_runs_30d: 0,
      success_rate_last_50: 0,
      avg_duration_ms_last_50: nil,
      runs_trend_14d: (0...14).map { |offset| { day: (Date.current - (13 - offset)).strftime("%m-%d"), count: 0 } },
      status_mix_30d: { queued: 0, running: 0, succeeded: 0, failed: 0 },
      latest_run: nil,
      latest_global: nil,
      top_accounts: [
        {
          account_id: account_id,
          total_pnl_quote: BigDecimal(total_pnl_quote),
          realized_net_pnl_quote: BigDecimal(total_pnl_quote),
          unrealized_pnl_quote: BigDecimal("0.0")
        }
      ]
    }
  end

  def admin_session_headers
    { "X-Admin-User" => "alice", "X-Admin-Role" => "viewer" }
  end
end
