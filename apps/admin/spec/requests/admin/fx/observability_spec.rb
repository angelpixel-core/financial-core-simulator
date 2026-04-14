require "rails_helper"
require "nokogiri"
require "json"

RSpec.describe "Admin FX observability", type: :request do
  let(:modern_user_agent) do
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_2_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
  end

  before do
    allow_any_instance_of(ActionDispatch::Request)
      .to receive(:user_agent)
      .and_return(modern_user_agent)
    allow_any_instance_of(ActionController::AllowBrowser::BrowserBlocker)
      .to receive(:blocked?)
      .and_return(false)
    host! "localhost"
  end

  def admin_t(key, locale: I18n.locale)
    I18n.t("admin.#{key}", locale: locale)
  end

  def admin_session_headers(role)
    {
      "X-Admin-User" => "alice",
      "X-Admin-Role" => role,
      "Accept" => "text/html",
      "HTTP_ACCEPT" => "text/html",
      "User-Agent" => modern_user_agent,
      "HTTP_USER_AGENT" => modern_user_agent
    }
  end

  def create_source(name:, code:)
    FxRateSource.create!(
      name: name,
      code: code,
      source_type: "api",
      version: "v1",
      config: {
        "base_currency" => "USD",
        "quote_currency" => "ARS",
        "base_url" => "https://example.com",
        "currency_code" => "USD"
      }
    )
  end

  shared_examples "observability page" do |role|
    it "renders the page for #{role}" do
      get "/admin/fx/observability", params: {format: :html}, headers: admin_session_headers(role)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(admin_t("fx.observability.title", locale: :en))
      expect(response.body).to include('data-controller="fx--observability--chart"')
      expect(response.body).to include(admin_t("fx.observability.filter.label", locale: :en))
    end
  end

  include_examples "observability page", "operator"
  include_examples "observability page", "admin"

  it "filters by source and range" do
    travel_to(Time.zone.parse("2026-04-10 09:00:00")) do
      source_a = create_source(name: "Banco Central", code: "BCRA")
      source_b = create_source(name: "Alternate Source", code: "ALT")

      FxRateIngestion.create!(source: source_a, status: "success", correlation_id: "c1",
        created_at: Time.zone.parse("2026-04-09 10:00:00"))
      FxRateIngestion.create!(source: source_a, status: "failed", error_code: "http_error",
        correlation_id: "c2", created_at: Time.zone.parse("2026-04-09 11:00:00"))
      FxRateIngestion.create!(source: source_b, status: "success", correlation_id: "c3",
        created_at: Time.zone.parse("2026-04-01 10:00:00"))

      get "/admin/fx/observability", params: {source_id: source_a.id, days: 7, format: :html},
        headers: admin_session_headers("admin")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Banco Central")

      doc = Nokogiri::HTML(response.body)
      chart = doc.at_css('[data-controller="fx--observability--chart"]')
      points = JSON.parse(chart["data-fx--observability--chart-points-value"])
      expect(points.length).to eq(1)
      expect(points.first).to include("label" => "Banco Central", "success" => 1, "failed" => 1)
    end
  end
end
