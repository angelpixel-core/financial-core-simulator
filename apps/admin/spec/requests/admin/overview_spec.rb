require "rails_helper"
require "bcrypt"
require "json"
require "nokogiri"
require "tmpdir"

RSpec.describe "Admin overview", type: :request do
  def admin_t(key, locale: I18n.locale)
    I18n.t("admin.#{key}", locale: locale)
  end

  it "renders empty state without exploding when no runs exist" do
    get "/admin/overview", headers: admin_session_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(admin_t("overview.hero.title", locale: :en))
    expect(response.body).to include(admin_t("overview.hero.eyebrow", locale: :en))
    expect(response.body).to include(admin_t("overview.system_metrics.title", locale: :en))
    expect(response.body).to include(admin_t("overview.financial_overview.title", locale: :en))
    expect(response.body).to include(admin_t("overview.financial_results.title", locale: :en))
    expect(response.body).to include('data-controller="poll"')
    control_index = response.body.index(admin_t("overview.hero.eyebrow", locale: :en))
    metrics_index = response.body.index(admin_t("overview.system_metrics.title", locale: :en))
    financial_overview_index = response.body.index(admin_t("overview.financial_overview.title", locale: :en))
    financial_index = response.body.index(admin_t("overview.financial_results.title", locale: :en))

    expect(control_index).to be < metrics_index
    expect(metrics_index).to be < financial_overview_index
    expect(financial_overview_index).to be < financial_index

    get admin_system_health_path, headers: admin_session_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(admin_t("overview.financial_results.latest_run.empty", locale: :en))
    expect(response.body).to include(admin_t("overview.validation.title", locale: :en))
  end

  it "exports trade activity dashboard as json on demand" do
    run = Run.create!(status: :succeeded, input_json: {"schemaVersion" => "1.0"})
    snapshot = RunSnapshot.create!(run: run, operational_date: Date.new(2026, 3, 29), reporting_currency: "USD")
    RunDailyVolume.create!(
      run_snapshot: snapshot,
      notional_volume: 100,
      trade_count: 3,
      unit_type: "quote",
      unit_code: "USD"
    )

    get admin_overview_export_path(card_type: "trade-activity-dashboard", run_id: run.id, format: :json),
      headers: admin_session_headers

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/json")
    expect(response.headers["Content-Disposition"]).to include("trade-activity-dashboard.json")

    payload = JSON.parse(response.body)
    expect(payload.dig("dashboard", "id")).to eq("trade-activity-dashboard")
    expect(payload.dig("run", "id")).to eq(run.id)
    expect(payload["data"]).to be_an(Array)
  end

  it "exports profit and loss dashboard as pdf on demand" do
    run = Run.create!(status: :succeeded, input_json: {"schemaVersion" => "1.0"})
    snapshot = RunSnapshot.create!(run: run, operational_date: Date.new(2026, 3, 29), reporting_currency: "USD")
    RunDailyPnl.create!(run_snapshot: snapshot, realized_pnl: 10, unrealized_pnl: 5, total_pnl: 15)

    get admin_overview_export_path(card_type: "profit-and-loss-dashboard", run_id: run.id, format: :pdf),
      headers: admin_session_headers

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/pdf")
    expect(response.headers["Content-Disposition"]).to include("profit-and-loss-dashboard.pdf")
    expect(response.body.bytesize).to be > 100
  end

  it "renders Spanish labels when locale is set" do
    get "/admin/overview", params: {locale: "es"}, headers: admin_session_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(admin_t("overview.hero.title", locale: :es))
    expect(response.body).to include(admin_t("overview.hero.eyebrow", locale: :es))
    expect(response.body).to include(admin_t("overview.financial_overview.title", locale: :es))

    nav_labels = Nokogiri::HTML(response.body)
      .css(".app-shell__nav--desktop a")
      .map { |node| node.text.strip }

    expect(nav_labels).to include(
      admin_t("nav.overview", locale: :es),
      admin_t("nav.history", locale: :es),
      admin_t("nav.runs", locale: :es)
    )

    get admin_system_health_path, params: {locale: "es"}, headers: admin_session_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(admin_t("overview.activity.run_trend.title", locale: :es))
    expect(response.body).to include(admin_t("overview.activity.status_mix.title", locale: :es))
  end

  it "keeps state-first navigation sequence discoverable in the shell" do
    get "/admin/overview", headers: admin_session_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(%(href="#{admin_system_health_path}"))

    overview_index = response.body.index(admin_t("nav.overview", locale: :en))
    history_index = response.body.index(admin_t("nav.history", locale: :en))
    runs_index = response.body.index(admin_t("nav.runs", locale: :en))
    expect(overview_index).to be < history_index
    expect(history_index).to be < runs_index
  end

  it "renders authenticated shell identity and logout affordance on overview" do
    Account.create!(
      email: "ops-shell@example.com",
      status: :verified,
      password_hash: BCrypt::Password.create("secret-pass")
    )

    post "/admin/login", params: {email: "ops-shell@example.com", password: "secret-pass"}
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

    post "/admin/login", params: {email: "ops@example.com", password: "secret-pass"}
    expect(response).to have_http_status(:found)

    get "/admin/overview"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("OPERATOR WORKSPACE")
    expect(response.body).not_to include("GitHub")

    nav_labels = Nokogiri::HTML(response.body)
      .css(".app-shell__nav--desktop a")
      .map { |node| node.text.strip }

    expect(nav_labels).to include(
      admin_t("nav.overview", locale: :en),
      admin_t("nav.history", locale: :en),
      admin_t("nav.runs", locale: :en)
    )
    expect(nav_labels).not_to include(admin_t("nav.support", locale: :en))
  end

  it "renders admin-specific shell with sensitive runs icon and no github links" do
    Account.create!(
      email: "admin@example.com",
      status: :verified,
      password_hash: BCrypt::Password.create("secret-pass")
    )

    post "/admin/login", params: {email: "admin@example.com", password: "secret-pass"}
    expect(response).to have_http_status(:found)

    get "/admin/overview"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("admin-shell-header--admin")
    expect(response.body).to include(admin_t("nav.runs", locale: :en))
    expect(response.body).to include("app-shell__nav-icon--sensitive")
    expect(response.body).to include(admin_t("nav.support", locale: :en))
    expect(response.body).to include(%(href="#{Avo.configuration.root_path}"))
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

  it "renders drilldown links for activity, latest run, and ingestion errors" do
    run = Run.create!(
      status: :succeeded,
      input_hash: "abc123",
      schema_version: "1.0",
      engine_version: "1.0"
    )

    get "/admin/overview", headers: admin_session_headers

    expect(response).to have_http_status(:ok)
    get admin_system_health_path, headers: admin_session_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(admin_t("overview.activity.run_trend.link", locale: :en))
    expect(response.body).to include(admin_t("overview.activity.status_mix.link", locale: :en))
    expect(response.body).to include(admin_t("overview.financial_results.latest_run.link", locale: :en))
    expect(response.body).to include(admin_t("overview.validation.cta_label", locale: :en))
    expect(response.body).to include(%(href="#{admin_overview_runs_trend_path}"))
    expect(response.body).to include(%(href="#{admin_overview_status_mix_path}"))
    expect(response.body).to include(%(href="#{admin_overview_ingestion_validation_errors_path}"))
    expect(response.body).to include(%(href="/admin/resources/runs/#{run.id}"))
  end

  it "renders dedicated runs trend and status mix pages" do
    get admin_overview_runs_trend_path, headers: admin_session_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(admin_t("overview.runs_trend.title", locale: :en))
    expect(response.body).to include(admin_t("overview.runs_trend.widget_title", locale: :en))
    expect(response.body).to include('data-controller="run-trend-chart"')
    expect(response.body).to include('data-run-trend-chart-target="chart"')
    expect(response.body).to include('data-run-trend-chart-target="fallback"')
    expect(response.body).to include('data-run-trend-chart-chart-kind-value="bar"')
    expect(response.body).to include("data-run-trend-chart-tooltip-label-value=\"#{admin_t("common.day",
      locale: :en)}\"")
    expect(response.body).to include("data-run-trend-chart-tooltip-count-label-value=\"#{admin_t("common.runs",
      locale: :en)}\"")
    expect(response.body).to include('data-run-trend-chart-animation-mode-value="proportional"')
    expect(response.body).to include('data-run-trend-chart-base-duration-value="260"')
    expect(response.body).to include('data-run-trend-chart-max-extra-duration-value="540"')
    expect(response.body).to include('title="')
    expect(response.body).to include('runs"')

    get admin_overview_status_mix_path, headers: admin_session_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(admin_t("overview.status_mix.title", locale: :en))
    expect(response.body).to include(admin_t("overview.status_mix.widget_title", locale: :en))
  end

  it "keeps trend chart hook and fallback nodes coexisting in system health" do
    get admin_system_health_path, headers: admin_session_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('data-controller="run-trend-chart"')
    expect(response.body).to include('data-run-trend-chart-target="chart"')
    expect(response.body).to include('data-run-trend-chart-target="fallback"')
    expect(response.body).to include('data-run-trend-chart-chart-kind-value="bar"')
    expect(response.body).to include('data-run-trend-chart-animation-mode-value="proportional"')
    expect(response.body).to include('data-run-trend-chart-base-duration-value="260"')
    expect(response.body).to include('data-run-trend-chart-max-extra-duration-value="540"')
  end

  it "renders derived simulation context and traceability cards when data is available" do
    previous_run = Run.create!(
      status: :succeeded,
      created_at: 2.days.ago,
      input_hash: "deterministic-hash",
      input_json: {
        "schemaVersion" => "1.0",
        "dataset" => "demo_input.json",
        "events" => [
          {"eventId" => "evt-1", "marketId" => "BTC-USD"},
          {"eventId" => "evt-2", "marketId" => "ETH-USD"}
        ],
        "accounts" => [{"accountId" => "acc-1"}, {"accountId" => "acc-2"}]
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
          {"eventId" => "evt-1", "marketId" => "BTC-USD"},
          {"eventId" => "evt-2", "marketId" => "ETH-USD"}
        ],
        "accounts" => [{"accountId" => "acc-1"}, {"accountId" => "acc-2"}]
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
          {"accountId" => "acc-1", "totals" => {"totalPnLQuote" => "20.0"}},
          {"accountId" => "acc-2", "totals" => {"totalPnLQuote" => "22.25"}}
        ]
      }

      File.write(previous_path, JSON.pretty_generate(payload))
      File.write(latest_path, JSON.pretty_generate(payload))
      File.write(positions_path, "account,qty\nacc-1,10\n")
      File.write(pnl_path, "account,total\nacc-1,42.25\n")

      previous_run.update!(artifacts: {"result_json_path" => previous_path})
      latest_run.update!(artifacts: {
        "result_json_path" => latest_path,
        "positions_csv_path" => positions_path,
        "pnl_csv_path" => pnl_path
      })

      get "/admin/overview", headers: admin_session_headers

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(admin_t("overview.financial_results.title", locale: :en))
      expect(response.body).not_to include(admin_t("overview.simulation_context.title", locale: :en))
      expect(response.body).not_to include(admin_t("overview.financial_results.input_traceability.title", locale: :en))
    end
  end

  it "keeps run trend chart and fallback markup across mobile and desktop detail views" do
    [375, 1280].each do |viewport_width|
      get admin_overview_runs_trend_path,
        headers: admin_session_headers.merge("X-Viewport-Width" => viewport_width.to_s)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('data-controller="run-trend-chart"')
      expect(response.body).to include('data-run-trend-chart-target="chart"')
      expect(response.body).to include('data-run-trend-chart-target="fallback"')
      expect(response.body).to include("trend-chart trend-chart--detail")
    end
  end

  it "renders count-up data hooks for all system KPI cards with numeric values" do
    run = Run.create!(status: :succeeded, created_at: 1.day.ago, input_json: {"schemaVersion" => "1.0"})
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

    expect(response).to have_http_status(:found)
    expect(response.headers["Location"]).to include("/admin/overview")
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

    get "/admin/overview/top-accounts", headers: admin_session_headers.merge("X-Requested-With" => "XMLHttpRequest")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(admin_t("overview.top_accounts.widget_title", locale: :en))
  end

  it "renders top accounts fragment for xhr polling" do
    get "/admin/overview/top-accounts", headers: admin_session_headers.merge("X-Requested-With" => "XMLHttpRequest")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(admin_t("overview.top_accounts.widget_title", locale: :en))
    expect(response.body).not_to include(admin_t("overview.top_accounts.cta_label", locale: :en))
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

    get "/admin/overview/top-accounts", headers: {"X-Requested-With" => "XMLHttpRequest"}

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

    get "/admin/overview", headers: {"X-Admin-Token" => "ui-secret"}

    expect(response).to have_http_status(:found)
    expect(response.headers["Location"]).to end_with("/")
  end

  it "allows access via role-based policy when ADMIN_UI_TOKEN is set" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_UI_TOKEN").and_return("ui-secret")

    get "/admin/overview", headers: {"X-Admin-User" => "alice", "X-Admin-Role" => "viewer"}

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
    run = Run.create!(status: :succeeded, input_json: {"schemaVersion" => "1.0"})
    path = File.join(dir, "result.json")
    File.write(path, JSON.pretty_generate(result_payload(account_id: account_id, total_pnl_quote: total_pnl_quote)))
    run.update!(artifacts: {"result_json_path" => path})
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
      runs_trend_14d: (0...14).map { |offset| {day: (Date.current - (13 - offset)).strftime("%m-%d"), count: 0} },
      status_mix_30d: {queued: 0, running: 0, succeeded: 0, failed: 0},
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
    {"X-Admin-User" => "alice", "X-Admin-Role" => "viewer"}
  end
end
