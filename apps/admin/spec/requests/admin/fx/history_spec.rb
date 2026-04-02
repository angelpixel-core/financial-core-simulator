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

    get "/admin/fx/history", headers: admin_session_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("USD/ARS")
    expect(response.body).to include("BTC/USD")
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

  def admin_session_headers
    {"X-Admin-User" => "alice", "X-Admin-Role" => "viewer"}
  end
end
