require "rails_helper"
require "bcrypt"
require "json"
require "nokogiri"
require "pathname"
require "tmpdir"

RSpec.describe "Admin overview", type: :request do
  it "renders empty state without exploding when no runs exist" do
    get "/admin/overview", headers: admin_session_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Financial Overview")
    expect(response.body).to include("CONTROL")
    expect(response.body).to include("SYSTEM STATE")
    expect(response.body).to include("SIMULATION CONTEXT")
    expect(response.body).to include("SYSTEM METRICS")
    expect(response.body).to include("ACTIVITY")
    expect(response.body).to include("FINANCIAL RESULTS")
    expect(response.body).to include("DATA QUALITY")
    expect(response.body).to include("No succeeded runs yet.")
    expect(response.body).to include("No PnL trend data available yet.")
    expect(response.body).to include("No simulation context available yet.")
    expect(response.body).to include("Comparison unavailable (need at least two succeeded runs).")
    expect(response.body).to include("No traceability metadata available yet.")
    expect(response.body).to include("Run trend (14d)")
    expect(response.body).to include("Status mix (30d)")
    expect(response.body).to include("data-controller=\"poll\"")
    control_index = response.body.index("CONTROL")
    state_index = response.body.index("SYSTEM STATE")
    simulation_context_index = response.body.index("SIMULATION CONTEXT")
    metrics_index = response.body.index("SYSTEM METRICS")
    activity_index = response.body.index("ACTIVITY")
    financial_index = response.body.index("FINANCIAL RESULTS")
    quality_index = response.body.index("DATA QUALITY")

    expect(control_index).to be < state_index
    expect(state_index).to be < simulation_context_index
    expect(simulation_context_index).to be < metrics_index
    expect(metrics_index).to be < activity_index
    expect(activity_index).to be < financial_index
    expect(financial_index).to be < quality_index
  end

  it "keeps state-first navigation sequence discoverable in the shell" do
    get "/admin/overview", headers: admin_session_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Open Latest Reliable Run")

    overview_index = response.body.index("Overview")
    runs_index = response.body.index("Runs")
    validation_index = response.body.index("Validation")
    artifacts_index = response.body.index("Artifacts")

    expect(overview_index).to be < runs_index
    expect(runs_index).to be < validation_index
    expect(validation_index).to be < artifacts_index
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

  it "renders operator-specific workspace shell navigation and header label" do
    Account.create!(
      email: "ops@example.com",
      status: :verified,
      password_hash: BCrypt::Password.create("secret-pass")
    )

    post "/admin/login", params: { email: "ops@example.com", password: "secret-pass" }
    expect(response).to have_http_status(:found)

    get "/admin/overview"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("OPERATOR WORKSPACE")
    expect(response.body).not_to include("GitHub")

    nav_labels = Nokogiri::HTML(response.body)
      .css(".app-shell__nav--desktop a")
      .map { |node| node.text.strip }

    expect(nav_labels).to include("Overview", "Validation", "Artifacts", "Docs")
    expect(nav_labels).not_to include("Runs")
  end

  it "renders admin-specific shell with sensitive runs icon and no github links" do
    Account.create!(
      email: "admin@example.com",
      status: :verified,
      password_hash: BCrypt::Password.create("secret-pass")
    )

    post "/admin/login", params: { email: "admin@example.com", password: "secret-pass" }
    expect(response).to have_http_status(:found)

    get "/admin/overview"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("admin-shell-header--admin")
    expect(response.body).to include("Runs")
    expect(response.body).to include("app-shell__nav-icon--sensitive")
    expect(response.body).to include("Docs")
    expect(response.body).not_to include("GitHub")
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
    expect(response.body).to include(run_result_path(id: run.id))

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
    expect(response.body).to include('data-run-trend-chart-chart-kind-value="bar"')
    expect(response.body).to include('data-run-trend-chart-tooltip-label-value="Day"')
    expect(response.body).to include('data-run-trend-chart-tooltip-count-label-value="Runs"')
    expect(response.body).to include('data-run-trend-chart-animation-mode-value="proportional"')
    expect(response.body).to include('data-run-trend-chart-base-duration-value="260"')
    expect(response.body).to include('data-run-trend-chart-max-extra-duration-value="540"')
    expect(response.body).to include('title="')
    expect(response.body).to include('runs"')

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
    expect(response.body).to include('data-run-trend-chart-chart-kind-value="bar"')
    expect(response.body).to include('data-run-trend-chart-animation-mode-value="proportional"')
    expect(response.body).to include('data-run-trend-chart-base-duration-value="260"')
    expect(response.body).to include('data-run-trend-chart-max-extra-duration-value="540"')
    expect(response.body).to include("No PnL trend data available yet.")
  end

  it "renders pnl trend chart hooks when successful runs include canonical pnl values" do
    run = Run.create!(
      status: :succeeded,
      valuation_timestamp: Time.zone.parse("2026-03-14T04:00:00Z"),
      input_json: { "schemaVersion" => "1.0" }
    )

    Dir.mktmpdir do |dir|
      path = File.join(dir, "result.json")
      File.write(path, JSON.pretty_generate({ "global" => { "totalPnLQuote" => "42.25" }, "accounts" => [] }))
      run.update!(artifacts: { "result_json_path" => path })

      get "/admin/overview", headers: admin_session_headers

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('data-controller="pnl-trend-chart"')
      expect(response.body).to include('data-pnl-trend-chart-target="chart"')
      expect(response.body).to include('<turbo-frame id="pnl_trend_fallback"')
      expect(response.body).to include('data-pnl-trend-chart-tooltip-label-value="Total PnL Quote"')
      expect(response.body).to include("Global total PnL quote over successful runs")
    end
  end

  it "renders derived simulation context, run comparison, and traceability cards when data is available" do
    previous_run = Run.create!(
      status: :succeeded,
      created_at: 2.days.ago,
      input_hash: "deterministic-hash",
      input_json: {
        "schemaVersion" => "1.0",
        "dataset" => "demo_input.json",
        "events" => [
          { "eventId" => "evt-1", "marketId" => "BTC-USD" },
          { "eventId" => "evt-2", "marketId" => "ETH-USD" }
        ],
        "accounts" => [ { "accountId" => "acc-1" }, { "accountId" => "acc-2" } ]
      }
    )

    latest_run = Run.create!(
      status: :succeeded,
      created_at: 1.day.ago,
      input_hash: "deterministic-hash",
      schema_version: "1.0",
      engine_version: "0.1.0",
      input_json: {
        "schemaVersion" => "1.0",
        "dataset" => "demo_input.json",
        "events" => [
          { "eventId" => "evt-1", "marketId" => "BTC-USD" },
          { "eventId" => "evt-2", "marketId" => "ETH-USD" }
        ],
        "accounts" => [ { "accountId" => "acc-1" }, { "accountId" => "acc-2" } ]
      }
    )

    Dir.mktmpdir do |dir|
      previous_path = File.join(dir, "result-previous.json")
      latest_path = File.join(dir, "result-latest.json")
      positions_path = File.join(dir, "positions.csv")
      pnl_path = File.join(dir, "pnl.csv")

      payload = {
        "global" => {
          "totalPnLQuote" => "42.25",
          "realizedNetPnLQuote" => "21.0",
          "unrealizedPnLQuote" => "21.25"
        },
        "accounts" => [
          { "accountId" => "acc-1", "totals" => { "totalPnLQuote" => "20.0" } },
          { "accountId" => "acc-2", "totals" => { "totalPnLQuote" => "22.25" } }
        ]
      }

      File.write(previous_path, JSON.pretty_generate(payload))
      File.write(latest_path, JSON.pretty_generate(payload))
      File.write(positions_path, "account,qty\nacc-1,10\n")
      File.write(pnl_path, "account,total\nacc-1,42.25\n")

      previous_run.update!(artifacts: { "result_json_path" => previous_path })
      latest_run.update!(artifacts: {
        "result_json_path" => latest_path,
        "positions_csv_path" => positions_path,
        "pnl_csv_path" => pnl_path
      })

      get "/admin/overview", headers: admin_session_headers

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("SIMULATION CONTEXT")
      expect(response.body).to include("demo_input.json")
      expect(response.body).to include("Run comparison")
      expect(response.body).to include("Identical output for matching input hash.")
      expect(response.body).to include("Input traceability")
      expect(response.body).to include(Pathname(latest_path).relative_path_from(Rails.root).to_s)
      expect(response.body).to include(Pathname(positions_path).relative_path_from(Rails.root).to_s)
      expect(response.body).to include(Pathname(pnl_path).relative_path_from(Rails.root).to_s)
    end
  end

  it "keeps run trend chart and fallback markup across mobile and desktop detail views" do
    [ 375, 1280 ].each do |viewport_width|
      get admin_overview_runs_trend_path,
headers: admin_session_headers.merge("X-Viewport-Width" => viewport_width.to_s)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('data-controller="run-trend-chart"')
      expect(response.body).to include('data-run-trend-chart-target="chart"')
      expect(response.body).to include('data-run-trend-chart-target="fallback"')
      expect(response.body).to include('trend-chart trend-chart--detail')
    end
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
        live_instance = instance_double("Admin::LiveStateMetrics",
call: live_metrics_for(account_id: "acc-live", total_pnl_quote: "77.0"))
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
