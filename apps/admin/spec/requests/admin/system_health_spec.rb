require "rails_helper"
require "json"
require "nokogiri"
require "tmpdir"

RSpec.describe "Admin system health", type: :request do
  def admin_t(key, locale: I18n.locale)
    I18n.t("admin.#{key}", locale: locale)
  end

  it "renders system health for viewer session" do
    get "/admin/system-health", headers: admin_session_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(admin_t("nav.runs", locale: :en))
  end

  it "renders pnl trend empty state when no runs exist" do
    get "/admin/system-health", headers: admin_session_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(admin_t("overview.activity.pnl_trend.empty_title", locale: :en))
    expect(response.body).to include(admin_t("fx.observability.events.title", locale: :en))
    expect(response.body).to include(admin_t("fx.observability.events.empty", locale: :en))
    expect(response.body).not_to include(admin_t("overview.financial_results.title", locale: :en))
    expect(response.body).not_to include(admin_t("overview.financial_results.latest_run.title", locale: :en))
    expect(response.body).not_to include(admin_t("overview.financial_results.run_comparison.title", locale: :en))
  end

  it "renders pnl trend chart hooks when successful runs include canonical pnl values" do
    run = Run.create!(
      status: :succeeded,
      valuation_timestamp: Time.zone.parse("2026-03-14T04:00:00Z"),
      input_json: {"schemaVersion" => "1.0"}
    )

    Dir.mktmpdir do |dir|
      path = File.join(dir, "result.json")
      File.write(path, JSON.pretty_generate({"global" => {"totalPnLQuote" => "42.25"}, "accounts" => []}))
      run.update!(artifacts: {"result_json_path" => path})

      get "/admin/system-health", headers: admin_session_headers

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('data-controller="pnl-trend-chart"')
      expect(response.body).to include('data-pnl-trend-chart-target="chart"')
      expect(response.body).to include('<turbo-frame id="pnl_trend_fallback"')
      expect(response.body).to include("data-pnl-trend-chart-tooltip-label-value=\"#{admin_t(
        "overview.activity.pnl_trend.tooltip", locale: :en
      )}\"")
      expect(response.body).to include(admin_t("overview.activity.pnl_trend.meta", locale: :en))
    end
  end

  it "renders recent events and hides financial results when recent runs exist" do
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

      previous_run.update!(artifacts: {"result_json_path" => previous_path})
      latest_run.update!(artifacts: {"result_json_path" => latest_path})

      get "/admin/system-health", headers: admin_session_headers

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(admin_t("fx.observability.events.title", locale: :en))
      expect(response.body).not_to include(admin_t("overview.financial_results.title", locale: :en))
      expect(response.body).not_to include(admin_t("overview.financial_results.latest_run.title", locale: :en))
      expect(response.body).not_to include(admin_t("overview.financial_results.global_pnl.title", locale: :en))
      expect(response.body).not_to include(admin_t("overview.financial_results.run_comparison.title", locale: :en))
    end
  end

  it "paginates FX observability events with ten events per page" do
    source = FxRateSource.create!(
      name: "BCRA",
      code: "BCRA",
      source_type: "api",
      version: "v1",
      config: {"base_url" => "https://example.test"}
    )

    11.times do |index|
      timestamp = index.minutes.ago
      FxRateEvent.create!(
        event_type: "event-#{index}",
        data: {
          "source_id" => source.id.to_s,
          "source_code" => source.code,
          "error_code" => "ERR_#{index}",
          "severity" => "warning"
        },
        metadata: {"ingestion_id" => (100 + index).to_s},
        created_at: timestamp,
        updated_at: timestamp
      )
    end

    get "/admin/system-health", headers: admin_session_headers

    expect(response).to have_http_status(:ok)
    document = Nokogiri::HTML(response.body)
    expect(document.css(".fx-observability-timeline__item").count).to eq(10)
    expect(response.body).to include("event-0")
    expect(response.body).to include("event-9")
    expect(response.body).not_to include("event-10")
    expect(response.body).to include(admin_t("fx.observability.events.pagination_aria", locale: :en))

    get "/admin/system-health", params: {events_page: 2}, headers: admin_session_headers

    expect(response).to have_http_status(:ok)
    document = Nokogiri::HTML(response.body)
    expect(document.css(".fx-observability-timeline__item").count).to eq(1)
    expect(response.body).to include("event-10")
    expect(response.body).not_to include("event-0")
  end

  def admin_session_headers
    {"X-Admin-User" => "alice", "X-Admin-Role" => "viewer"}
  end
end
