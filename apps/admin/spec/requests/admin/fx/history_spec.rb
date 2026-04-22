require "rails_helper"
require "nokogiri"

RSpec.describe "Admin FX history", type: :request do
  def admin_t(key, locale: I18n.locale)
    I18n.t("admin.#{key}", locale: locale)
  end

  it "renders empty history state when no rates exist" do
    get "/admin/fx/history", headers: admin_session_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(admin_t("fx.history.title", locale: :en))
    expect(response.body).to include(admin_t("fx.history.empty", locale: :en))
  end

  it "renders supported pair sections when rates exist" do
    FxDailyRate.create!(
      operational_date: Date.new(2026, 3, 30),
      base_currency: "USD",
      quote_currency: "ARS",
      rate: "1000",
      source: "manual"
    )
    FxDailyRate.create!(
      operational_date: Date.new(2026, 3, 30),
      base_currency: "BTC",
      quote_currency: "USD",
      rate: "62000",
      source: "manual"
    )

    get "/admin/fx/history", headers: admin_session_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(admin_t("fx.history.charts.fiat.title", locale: :en))
    expect(response.body).to include(admin_t("fx.history.charts.crypto.title", locale: :en))
    expect(response.body).to include('data-controller="fx--market-line-chart"')
    expect(response.body).to include("ARS/USD")
    expect(response.body).to include("ARS/EUR")
    expect(response.body).to include("BTC/USD")
    expect(response.body).to include("USD/ARS")
    expect(response.body).to include("EUR/ARS")
    expect(response.body).to include("BTC/ARS")
    expect(response.body).to include("ETH/USD")
    expect(response.body).to include("ETH/ARS")
  end

  it "renders localized history nav label in Spanish" do
    get "/admin/fx/history", params: {locale: "es"}, headers: admin_session_headers

    expect(response).to have_http_status(:ok)
    nav_labels = Nokogiri::HTML(response.body)
      .css(".app-shell__nav--desktop a")
      .map { |node| node.text.strip }

    expect(nav_labels).to include(admin_t("nav.history", locale: :es))
  end

  it "syncs configured sources into persistence for history" do
    FxRateSource.delete_all

    get "/admin/fx/history", headers: admin_session_headers(role: "viewer")

    expect(response).to have_http_status(:ok)
    source = FxRateSource.find_by(code: "BCRA")
    expect(source).to be_present
    expect(source.name).to eq("BCRA")
    expect(Admin::Fx::SourceCatalog.available_markets_for(source)).to include("USDARS", "EURARS")

    binance = FxRateSource.find_by(code: "BINANCE_SPOT")
    expect(binance).to be_present
    expect(Admin::Fx::SourceCatalog.available_markets_for(binance)).to include("BTCUSDT", "ETHUSDT")
  end

  it "paginates recent events with ten events per page" do
    11.times do |index|
      timestamp = index.minutes.ago
      FxRateEvent.create!(
        event_type: "event-#{index}",
        data: {"error_code" => "ERR_#{index}"},
        metadata: {},
        created_at: timestamp,
        updated_at: timestamp
      )
    end

    get "/admin/fx/history", headers: admin_session_headers

    expect(response).to have_http_status(:ok)
    document = Nokogiri::HTML(response.body)
    expect(document.css(".fx-history-events__item").count).to eq(10)
    expect(response.body).to include("event-0")
    expect(response.body).to include("event-9")
    expect(response.body).not_to include("event-10")
    expect(response.body).to include(admin_t("fx.history.events.pagination_aria", locale: :en))

    get "/admin/fx/history", params: {events_page: 2}, headers: admin_session_headers

    expect(response).to have_http_status(:ok)
    document = Nokogiri::HTML(response.body)
    expect(document.css(".fx-history-events__item").count).to eq(1)
    expect(response.body).to include("event-10")
    expect(response.body).not_to include("event-0")
  end

  def admin_session_headers(role: "viewer")
    {"X-Admin-User" => "alice", "X-Admin-Role" => role}
  end
end
